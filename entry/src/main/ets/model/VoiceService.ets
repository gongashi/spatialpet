import { audio } from '@kit.AudioKit'
import { http } from '@kit.NetworkKit'
import { common, abilityAccessCtrl } from '@kit.AbilityKit'
import { speechRecognizer } from '@kit.CoreSpeechKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'VoiceService'
const DOMAIN: number = 0xFF00

const API_BASE_URL: string = 'https://dashscope.aliyuncs.com/compatible-mode/v1'
const API_KEY: string = 'sk-e28ec115af2a4f2d95f475fb50e161e3'

interface ChatMessage {
  role: string
  content: string
}

interface ChatRequest {
  model: string
  messages: ChatMessage[]
  temperature: number
  max_tokens: number
}

export class VoiceService {
  private audioCapturer: audio.AudioCapturer | null = null
  private isRecording: boolean = false
  private context: common.Context | null = null
  private asrEngine: speechRecognizer.SpeechRecognitionEngine | null = null
  private sessionId: string = ''
  lastError: string = ''
  asrResult: string = ''
  private asrFinished: boolean = false

  private pcmBuffer: Uint8Array = new Uint8Array(0)

  init(context: common.Context): void {
    this.context = context
  }

  getIsRecording(): boolean {
    return this.isRecording
  }

  async requestMicPermission(): Promise<boolean> {
    if (this.context === null) {
      this.lastError = 'context is null'
      return false
    }
    try {
      let atManager = abilityAccessCtrl.createAtManager()
      let data = await atManager.requestPermissionsFromUser(this.context, ['ohos.permission.MICROPHONE'])
      let granted: boolean = data.authResults.length > 0 && data.authResults[0] === 0
      if (!granted) {
        this.lastError = 'MICROPHONE permission denied'
      }
      return granted
    } catch (e) {
      this.lastError = 'permission request failed: ' + String(e)
      return false
    }
  }

  private createAsrEngine(): Promise<boolean> {
    return new Promise<boolean>((resolve: Function, reject: Function) => {
      try {
        let extraParam: Record<string, Object> = { 'locate': 'CN', 'recognizerMode': 'short' }
        let initParamsInfo: speechRecognizer.CreateEngineParams = {
          language: 'zh-CN',
          online: 1,
          extraParams: extraParam
        }
        speechRecognizer.createEngine(initParamsInfo, (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
          if (err) {
            hilog.error(DOMAIN, TAG, 'ASR createEngine error: %{public}d %{public}s', err.code, err.message)
            this.lastError = 'ASR createEngine error: ' + err.code + ' ' + err.message
            resolve(false)
            return
          }
          hilog.info(DOMAIN, TAG, 'ASR engine created successfully')
          this.asrEngine = engine
          this.setupAsrListener()
          resolve(true)
        })
      } catch (e) {
        this.lastError = 'createAsrEngine failed: ' + String(e)
        resolve(false)
      }
    })
  }

  private setupAsrListener(): void {
    if (this.asrEngine === null) {
      return
    }
    let listener: speechRecognizer.RecognitionListener = {
      onStart: (sessionId: string, eventMessage: string): void => {
        hilog.info(DOMAIN, TAG, 'ASR onStart: %{public}s', eventMessage)
        this.lastError = 'ASR onStart: ' + eventMessage
      },
      onEvent: (sessionId: string, eventCode: number, eventMessage: string): void => {
        hilog.info(DOMAIN, TAG, 'ASR onEvent: %{public}d %{public}s', eventCode, eventMessage)
      },
      onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult): void => {
        hilog.info(DOMAIN, TAG, 'ASR onResult: isFinal=%{public}d result=%{public}s', result.isFinal ? 1 : 0, result.result)
        if (result.isFinal) {
          this.asrResult = result.result
          this.asrFinished = true
          this.lastError = 'ASR final: ' + result.result
        } else {
          this.lastError = 'ASR partial: ' + result.result
        }
      },
      onComplete: (sessionId: string, eventMessage: string): void => {
        hilog.info(DOMAIN, TAG, 'ASR onComplete: %{public}s', eventMessage)
        this.lastError = 'ASR onComplete: ' + eventMessage
        this.asrFinished = true
      },
      onError: (sessionId: string, errorCode: number, errorMessage: string): void => {
        hilog.error(DOMAIN, TAG, 'ASR onError: %{public}d %{public}s', errorCode, errorMessage)
        this.lastError = 'ASR onError: ' + errorCode + ' ' + errorMessage
        this.asrFinished = true
      }
    }
    this.asrEngine.setListener(listener)
  }

  async startRecording(): Promise<boolean> {
    if (this.isRecording) {
      return false
    }
    let granted: boolean = await this.requestMicPermission()
    if (!granted) {
      return false
    }
    this.asrResult = ''
    this.asrFinished = false
    try {
      let asrCreated: boolean = await this.createAsrEngine()
      hilog.info(DOMAIN, TAG, 'ASR engine created: %{public}d', asrCreated ? 1 : 0)
      if (!asrCreated) {
        this.lastError = 'ASR engine not created'
        return false
      }
      this.sessionId = 'asr_' + Date.now()
      let audioParam: speechRecognizer.AudioInfo = {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      }
      let extraParam: Record<string, Object> = { 'vadBegin': 2000, 'vadEnd': 3000, 'maxAudioDuration': 40000 }
      let recognizerParams: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: audioParam,
        extraParams: extraParam
      }
      let engine: speechRecognizer.SpeechRecognitionEngine = this.asrEngine!
      engine.startListening(recognizerParams)
      hilog.info(DOMAIN, TAG, 'ASR startListening called, sessionId=%{public}s', this.sessionId)

      let audioStreamInfo: audio.AudioStreamInfo = {
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      }
      let capturerInfo: audio.AudioCapturerInfo = {
        source: audio.SourceType.SOURCE_TYPE_MIC,
        capturerFlags: 0
      }
      let options: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: capturerInfo
      }
      this.audioCapturer = await audio.createAudioCapturer(options)
      this.pcmBuffer = new Uint8Array(0)
      this.audioCapturer.on('readData', (buffer: ArrayBuffer) => {
        if (!this.isRecording || this.asrEngine === null) {
          return
        }
        let incoming: Uint8Array = new Uint8Array(buffer)
        let merged: Uint8Array = new Uint8Array(this.pcmBuffer.length + incoming.length)
        merged.set(this.pcmBuffer)
        merged.set(incoming, this.pcmBuffer.length)
        let offset: number = 0
        let chunkSize: number = 640
        while (offset + chunkSize <= merged.length) {
          let chunk: Uint8Array = merged.subarray(offset, offset + chunkSize)
          let writeChunk: Uint8Array = new Uint8Array(chunkSize)
          writeChunk.set(chunk)
          this.asrEngine.writeAudio(this.sessionId, writeChunk)
          offset += chunkSize
        }
        this.pcmBuffer = merged.subarray(offset)
      })
      await this.audioCapturer.start()
      this.isRecording = true
      this.lastError = ''
      hilog.info(DOMAIN, TAG, 'Recording started successfully')
      return true
    } catch (e) {
      this.lastError = 'startRecording failed: ' + String(e)
      this.isRecording = false
      if (this.audioCapturer != null) {
        try {
          await this.audioCapturer.release()
        } catch (_) {
        }
        this.audioCapturer = null
      }
      return false
    }
  }

  async stopRecording(): Promise<string> {
    this.isRecording = false
    hilog.info(DOMAIN, TAG, 'stopRecording called')
    if (this.audioCapturer != null) {
      try {
        await this.audioCapturer.stop()
        await this.audioCapturer.release()
      } catch (e) {
        this.lastError = 'stopRecording release failed: ' + String(e)
        hilog.error(DOMAIN, TAG, 'stopRecording release failed: %{public}s', String(e))
      }
      this.audioCapturer = null
    }
    if (this.asrEngine !== null) {
      try {
        this.asrEngine.finish(this.sessionId)
        hilog.info(DOMAIN, TAG, 'ASR finish called')
      } catch (e) {
        this.lastError = 'ASR finish failed: ' + String(e)
        hilog.error(DOMAIN, TAG, 'ASR finish failed: %{public}s', String(e))
      }
    }
    let waitCount: number = 0
    while (!this.asrFinished && waitCount < 50) {
      await this.sleep(100)
      waitCount++
    }
    if (this.asrEngine !== null) {
      try {
        this.asrEngine.shutdown()
      } catch (_) {
      }
      this.asrEngine = null
    }
    return this.asrResult
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  async chatWithLLM(userText: string): Promise<string> {
    let httpClient = http.createHttp()
    let sysMsg: ChatMessage = { role: 'system', content: '你是灰灰，一只可爱的橙色猫咪精灵管家。你说话简短俏皮，喜欢用猫的方式表达，偶尔加喵~。你关心主人的饮食、作息和心情。' }
    let userMsg: ChatMessage = { role: 'user', content: userText }
    let chatReq: ChatRequest = {
      model: 'qwen3-max',
      messages: [sysMsg, userMsg],
      temperature: 0.7,
      max_tokens: 200
    }
    let requestBody: string = JSON.stringify(chatReq)
    try {
      let response = await httpClient.request(API_BASE_URL + '/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ' + API_KEY
        },
        extraData: requestBody,
        expectDataType: http.HttpDataType.STRING
      })
      if (response.responseCode === 200) {
        let resultStr: string = response.result as string
        let resultObj: Record<string, Object> = JSON.parse(resultStr) as Record<string, Object>
        let choices: Object[] = resultObj['choices'] as Object[]
        if (choices.length > 0) {
          let choice: Record<string, Object> = choices[0] as Record<string, Object>
          let message: Record<string, string> = choice['message'] as Record<string, string>
          return message['content']
        }
      }
      this.lastError = 'LLM HTTP ' + response.responseCode
      return '灰灰网络不太好喵~'
    } catch (e) {
      this.lastError = 'LLM failed: ' + String(e)
      return '灰灰连接失败喵~'
    } finally {
      httpClient.destroy()
    }
  }
}