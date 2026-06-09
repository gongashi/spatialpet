import { SpiritState, SpiritMood, SpiritMission } from '../model/SpiritModel'
import { TodoList, TodoItem } from '../model/TodoModel'
import { AlarmList, AlarmItem, CalendarAlarmService } from '../model/AlarmModel'
import { Scene, Camera, SceneResourceFactory, SceneNodeParameters, Light, LightType, Environment, EnvironmentBackgroundType, Image as GfxImage, SceneResourceParameters, Node } from '@kit.ArkGraphics3D'
import { common } from '@kit.AbilityKit'
import { VoiceService } from '../model/VoiceService'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { pasteboard } from '@kit.BasicServicesKit'

const TAG: string = 'SpatialPet'
const DOMAIN: number = 0xFF00

@Entry
@Component
struct Index {
  @State spirit: SpiritState = new SpiritState()
  @State todoList: TodoList = new TodoList()
  @State reactionText: string = ''
  @State showReaction: boolean = false
  @State spiritScale: number = 1.0
  @State spiritOffsetY: number = 0
  @State breathPhase: number = 0
  @State jumpOffset: number = 0
  @State wobbleAngle: number = 0
  @State tailAngle: number = 0
  @State faceTag: string = ''
  @State showFaceTag: boolean = false
  @State glowPulse: number = 0
  @State sparkles: number[] = []
  @State newTodoTitle: string = ''
  @State showAddTodoPanel: boolean = false
  @State showTodoList: boolean = false
  @State alarmHour: number = 7
  @State alarmMinute: number = 0
  @State showAlarmPanel: boolean = false
  @State alarmList: AlarmList = new AlarmList()
  @State isRecording: boolean = false
  @State chatMessages: string[] = []
  @State showChatPanel: boolean = false
  @State chatInput: string = ''
  @State use3D: boolean = false
  @State sceneOpt: SceneOptions | null = null
  @State loadMsg: string = ''
  @State rotY: number = 0
  @State rotX: number = 0
  private breathTimer: number = -1
  private decayTimer: number = -1
  private glowTimer: number = -1
  private sparkleTimer: number = -1
  private tailTimer: number = -1
  private autoRotTimer: number = -1
  private scene: Scene | null = null
  private cam: Camera | null = null
  private env: Environment | null = null
  private catNode: Node | null = null
  private voiceService: VoiceService = new VoiceService()
  private calendarAlarm: CalendarAlarmService = new CalendarAlarmService()

  aboutToAppear(): void {
    this.todoList.addItem('晨间锻炼', 2, 7, 0)
    this.todoList.addItem('阅读30分钟', 1, -1, -1)
    this.todoList.addItem('整理工作邮件', 1, 9, 0)
    this.spirit.taskCount = this.todoList.getPendingCount()
    this.spirit = this.spirit.copy()
    this.todoList = this.todoList.copy()
    this.startBreathing()
    this.startDecay()
    this.startGlowPulse()
    this.startTailWag()
    let ctx: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.voiceService.init(ctx)
    this.initCalendarAlarm(ctx)
    this.load3DScene()
  }

  async initCalendarAlarm(ctx: common.UIAbilityContext): Promise<void> {
    let ok: boolean = await this.calendarAlarm.initCalendar(ctx)
    hilog.info(DOMAIN, TAG, 'initCalendarAlarm result: %{public}d', ok ? 1 : 0)
    if (ok) {
      await this.calendarAlarm.clearAllAlarms()
      let list: AlarmList = await this.calendarAlarm.getAlarmList()
      this.alarmList = list.copy()
      hilog.info(DOMAIN, TAG, 'alarmList from calendar: %{public}d items', this.alarmList.items.length)
    }
  }

  async refreshAlarmListFromCalendar(): Promise<void> {
    let list: AlarmList = await this.calendarAlarm.getAlarmList()
    this.alarmList = list.copy()
    hilog.info(DOMAIN, TAG, 'alarmList refreshed: %{public}d items', this.alarmList.items.length)
  }

  aboutToDisappear(): void {
    if (this.breathTimer !== -1) clearInterval(this.breathTimer)
    if (this.decayTimer !== -1) clearInterval(this.decayTimer)
    if (this.glowTimer !== -1) clearInterval(this.glowTimer)
if (this.sparkleTimer !== -1) clearInterval(this.sparkleTimer)
      if (this.tailTimer !== -1) clearInterval(this.tailTimer)
    if (this.autoRotTimer !== -1) clearInterval(this.autoRotTimer)
  }

  async load3DScene(): Promise<void> {
    try {
      let result: Scene = await Scene.load($rawfile('pet/pet_cat.gltf'))
      this.scene = result
      let rf: SceneResourceFactory = result.getResourceFactory()
      this.catNode = result.getNodeByPath('CatRoot') as Node

      let camParams: SceneNodeParameters = { name: 'SpiritCam' }
      this.cam = await rf.createCamera(camParams)
      this.loadMsg = '3D加载成功'
      this.cam.enabled = true
      this.cam.position.z = 3.5
      this.cam.position.y = 0.8
      this.cam.position.x = 0
      this.cam.fov = 50 * Math.PI / 180

      let lightParams: SceneNodeParameters = { name: 'MainLight' }
      let mainLight: Light = await rf.createLight(lightParams, LightType.DIRECTIONAL)
      mainLight.enabled = true
      mainLight.intensity = 4.0
      mainLight.position.x = 2
      mainLight.position.y = 6
      mainLight.position.z = 4

      let fillParams: SceneNodeParameters = { name: 'FillLight' }
      let fillLight: Light = await rf.createLight(fillParams, LightType.DIRECTIONAL)
      fillLight.enabled = true
      fillLight.intensity = 2.0
      fillLight.position.x = -2
      fillLight.position.y = 4
      fillLight.position.z = -3

      let rimParams: SceneNodeParameters = { name: 'RimLight' }
      let rimLight: Light = await rf.createLight(rimParams, LightType.DIRECTIONAL)
      rimLight.enabled = true
      rimLight.intensity = 1.2
      rimLight.position.x = -1
      rimLight.position.y = 2
      rimLight.position.z = -5

      let imgParams: SceneResourceParameters = { name: 'skyImg', uri: $rawfile('pet/sky_env.png') }
      let envImg: GfxImage = await rf.createImage(imgParams)
      let envParams: SceneResourceParameters = { name: 'spiritEnv' }
      this.env = await rf.createEnvironment(envParams)
      this.env.backgroundType = EnvironmentBackgroundType.BACKGROUND_EQUIRECTANGULAR
      this.env.environmentImage = envImg
      this.env.indirectDiffuseFactor.x = 0.8
      this.env.indirectDiffuseFactor.y = 0.8
      this.env.indirectDiffuseFactor.z = 0.8
      this.env.indirectDiffuseFactor.w = 0.8
      this.env.indirectSpecularFactor.x = 1.0
      this.env.indirectSpecularFactor.y = 1.0
      this.env.indirectSpecularFactor.z = 1.0
      result.environment = this.env

      this.sceneOpt = { scene: this.scene, modelType: ModelType.SURFACE }
      this.use3D = true
      this.loadMsg = '3D加载成功'
      this.startAutoRotate()
    } catch (error) {
      this.use3D = false
      let errMsg: string = ''
      if (error instanceof Error) {
        errMsg = error.message + ' | ' + error.stack
      } else {
        errMsg = String(error)
      }
      this.loadMsg = '3D失败:' + errMsg.substring(0, 80)
      console.error('3D LOAD ERROR: ' + errMsg)
    }
  }

  startBreathing(): void {
    this.breathTimer = setInterval(() => {
      this.breathPhase = (this.breathPhase + 1) % 60
      this.spiritOffsetY = Math.sin(this.breathPhase * Math.PI / 30) * 8
    }, 100)
  }

  startDecay(): void {
    this.decayTimer = setInterval(() => {
      this.spirit.decay()
      this.spirit = this.spirit.copy()
    }, 5000)
  }

  startGlowPulse(): void {
    this.glowTimer = setInterval(() => { this.glowPulse = (this.glowPulse + 1) % 40 }, 80)
  }

  startTailWag(): void {
    this.tailTimer = setInterval(() => {
      this.tailAngle = Math.sin(Date.now() * 0.005) * 15
    }, 50)
  }

  startAutoRotate(): void {
    this.autoRotTimer = setInterval(() => {
      let phase: number = Date.now() * 0.001
      if (this.catNode != null) {
        let angle: number = phase * 0.5
        let halfAngle: number = angle * Math.PI / 180 * 0.5
        this.catNode.rotation.w = Math.cos(halfAngle)
        this.catNode.rotation.x = 0
        this.catNode.rotation.y = Math.sin(halfAngle)
        this.catNode.rotation.z = 0
      }
    }, 50)
  }

  doAction(action: () => string, tag: string): void {
    let msg: string = action()
    this.spirit = this.spirit.copy()
    this.reactionText = msg
    this.showReaction = true
    this.faceTag = tag
    this.showFaceTag = true
    this.triggerSparkles()
    animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.spiritScale = 1.15
      this.jumpOffset = -20
      this.wobbleAngle = 10
    })
    if (this.use3D && this.catNode != null) {
      let node: Node = this.catNode
      animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
        node.position.y = 0.5
      })
      setTimeout(() => {
        animateTo({ duration: 300, curve: Curve.EaseIn }, () => {
          node.position.y = 0
        })
      }, 400)
    }
    setTimeout(() => {
      animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
        this.spiritScale = 1.0
        this.jumpOffset = 0
        this.wobbleAngle = 0
      })
    }, 400)
    setTimeout(() => { this.showReaction = false }, 2500)
    setTimeout(() => { this.showFaceTag = false }, 3000)
  }

  triggerReaction(): void {
    this.showReaction = true
    this.reactionText = this.spirit.currentMessage
    this.triggerSparkles()
    animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
      this.spiritScale = 1.1
      this.jumpOffset = -15
    })
    setTimeout(() => {
      animateTo({ duration: 250, curve: Curve.EaseIn }, () => {
        this.spiritScale = 1.0
        this.jumpOffset = 0
      })
    }, 500)
    setTimeout(() => { this.showReaction = false }, 3000)
  }

  triggerSparkles(): void {
    this.sparkles = [0, 1, 2, 3, 4, 5, 6, 7]
    this.sparkleTimer = setInterval(() => {
      if (this.sparkles.length > 0) {
        this.sparkles = this.sparkles.filter((_: number, i: number) => i % 2 === 0)
      } else {
        clearInterval(this.sparkleTimer)
        this.sparkleTimer = -1
      }
    }, 300)
  }

  onTodoComplete(id: number): void {
    this.todoList.completeItem(id)
    this.todoList = this.todoList.copy()
    this.spirit.completedCount = this.todoList.getCompletedCount()
    this.spirit.taskCount = this.todoList.getPendingCount() + this.todoList.getCompletedCount()
    this.doAction(() => this.spirit.onTaskCompleted(), '🎉')
  }

  onAddTodo(): void {
    if (this.newTodoTitle.length > 0) {
      this.todoList.addItem(this.newTodoTitle, 0, -1, -1)
      this.todoList = this.todoList.copy()
      this.spirit.taskCount = this.todoList.getPendingCount() + this.todoList.getCompletedCount()
      this.spirit.onTaskAdded()
      this.spirit.currentMessage = '收到！已添加：' + this.newTodoTitle
      this.spirit = this.spirit.copy()
      this.newTodoTitle = ''
      this.showAddTodoPanel = false
      this.triggerReaction()
    }
  }

  async publishAlarmReminder(): Promise<void> {
    let item: AlarmItem | null = await this.calendarAlarm.addAlarm(this.alarmHour, this.alarmMinute, '手动闹钟')
    if (item !== null) {
      this.alarmList.add(item)
      this.alarmList = this.alarmList.copy()
      this.spirit.onMissionChange(SpiritMission.WAKE_UP)
      this.spirit.currentMessage = '好的！闹钟已设置 ' + this.alarmHour + ':' + (this.alarmMinute < 10 ? '0' : '') + this.alarmMinute
      this.spirit = this.spirit.copy()
      this.showAlarmPanel = false
      this.triggerReaction()
    } else {
      this.spirit.currentMessage = '闹钟设置失败喵...'
      this.spirit = this.spirit.copy()
      this.showAlarmPanel = false
      this.triggerReaction()
    }
  }

  async cancelAlarm(eventId: number): Promise<void> {
    let ok: boolean = await this.calendarAlarm.removeAlarm(eventId)
    if (ok) {
      this.alarmList.remove(eventId)
      this.alarmList = this.alarmList.copy()
      this.spirit.currentMessage = '闹钟已取消喵~'
      this.spirit = this.spirit.copy()
    } else {
      this.spirit.currentMessage = '取消闹钟失败喵...'
      this.spirit = this.spirit.copy()
    }
  }

  parseAlarmTimeFromText(text: string): number[] | null {
    let hourOffset: number = 0
    if (text.includes('下午') || text.includes('傍晚') || text.includes('晚上') || text.includes('晚间') || text.includes('夜里')) {
      hourOffset = 12
    }
    let separators: string[] = ['点', '时', ':', '：']
    for (let sep of separators) {
      let idx: number = text.indexOf(sep)
      if (idx > 0 && idx < text.length - 1) {
        let hourStr: string = ''
        let i: number = idx - 1
        while (i >= 0 && text.charAt(i) >= '0' && text.charAt(i) <= '9') {
          hourStr = text.charAt(i) + hourStr
          i--
        }
        let minuteStr: string = ''
        let j: number = idx + 1
        while (j < text.length && text.charAt(j) >= '0' && text.charAt(j) <= '9') {
          minuteStr = minuteStr + text.charAt(j)
          j++
        }
        if (hourStr.length === 0) {
          continue
        }
        let hour: number = parseInt(hourStr) + hourOffset
        let minute: number = 0
        if (minuteStr.length > 0) {
          minute = parseInt(minuteStr)
        }
        if (text.substring(idx).startsWith(sep + '半')) {
          minute = 30
        }
        if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
          return [hour, minute]
        }
      }
    }
    return null
  }

  async trySetAlarmFromChat(userText: string): Promise<boolean> {
    let alarmKeywords: string[] = ['闹钟', '提醒', '定时', '叫醒', '叫我', '提醒我', '设闹钟', '定闹钟', '设提醒']
    let hasAlarmIntent: boolean = false
    for (let keyword of alarmKeywords) {
      if (userText.includes(keyword)) {
        hasAlarmIntent = true
        break
      }
    }
    if (!hasAlarmIntent) {
      return false
    }
    hilog.info(DOMAIN, TAG, 'Alarm intent detected: %{public}s', userText)
    let timeArr: number[] | null = this.parseAlarmTimeFromText(userText)
    if (timeArr === null) {
      hilog.error(DOMAIN, TAG, 'Failed to parse alarm time from text')
      return false
    }
    let hour: number = timeArr[0]
    let minute: number = timeArr[1]
    hilog.info(DOMAIN, TAG, 'Parsed alarm time: %{public}d:%{public}d', hour, minute)
    let item: AlarmItem | null = await this.calendarAlarm.addAlarm(hour, minute, '对话闹钟')
    if (item !== null) {
      hilog.info(DOMAIN, TAG, 'Alarm event added, id: %{public}d', item.eventId)
      this.alarmList.add(item)
      this.alarmList = this.alarmList.copy()
      let alarmMsg: string = '主人让我定了' + hour + ':' + (minute < 10 ? '0' : '') + minute + '的闹钟，我已经设好了。请用猫的方式确认，简短俏皮。'
      let reply: string = await this.voiceService.chatWithLLM(alarmMsg)
      this.chatMessages.push('🐱 ' + reply)
      this.spirit.currentMessage = reply
      this.spirit.happiness = Math.min(100, this.spirit.happiness + 5)
      this.spirit.affinity = Math.min(100, this.spirit.affinity + 3)
      this.spirit = this.spirit.copy()
      return true
    } else {
      this.chatMessages.push('🐱 闹钟设置失败了喵...')
      this.spirit.currentMessage = '闹钟设置失败了喵...'
      this.spirit = this.spirit.copy()
      return true
    }
  }

  getGlowOpacity(): number {
    return 0.25 + Math.sin(this.glowPulse * Math.PI / 20) * 0.15
  }

  toggle3D(): void {
    this.use3D = !this.use3D
  }

  async startVoiceRecording(): Promise<void> {
    if (this.isRecording) {
      return
    }
    let started: boolean = await this.voiceService.startRecording()
    this.isRecording = started
    if (started) {
      this.chatMessages.push('🎤 正在录音...')
    } else {
      this.chatMessages.push('🎤 无法录音: ' + this.voiceService.lastError)
    }
  }

  async stopVoiceRecording(): Promise<void> {
    if (!this.isRecording) {
      return
    }
    let asrText: string = await this.voiceService.stopRecording()
    this.isRecording = false
    if (asrText.length > 0) {
      this.chatMessages.push('👤 ' + asrText)
      let reply: string = await this.voiceService.chatWithLLM(asrText)
      this.chatMessages.push('🐱 ' + reply)
      this.spirit.happiness = Math.min(100, this.spirit.happiness + 10)
      this.spirit.affinity = Math.min(100, this.spirit.affinity + 3)
      this.spirit.currentMessage = reply
      this.spirit = this.spirit.copy()
    } else {
      this.chatMessages.push('🎤 识别失败: ' + this.voiceService.lastError)
    }
  }

  async sendChatMessage(): Promise<void> {
    if (this.chatInput.length === 0) {
      return
    }
    this.chatMessages.push('👤 ' + this.chatInput)
    let userText: string = this.chatInput
    this.chatInput = ''
    let alarmHandled: boolean = await this.trySetAlarmFromChat(userText)
    if (!alarmHandled) {
      let reply: string = await this.voiceService.chatWithLLM(userText)
      this.chatMessages.push('🐱 ' + reply)
      this.spirit.currentMessage = reply
      this.spirit.happiness = Math.min(100, this.spirit.happiness + 5)
      this.spirit.affinity = Math.min(100, this.spirit.affinity + 2)
      this.spirit = this.spirit.copy()
    } else {
      this.spirit.currentMessage = '闹钟设好了喵~'
      this.spirit.happiness = Math.min(100, this.spirit.happiness + 5)
      this.spirit = this.spirit.copy()
    }
  }

  @Builder
  CatAvatar() {
    Stack() {
      Circle().width(240).height(240).fill(this.spirit.getGlowColor()).opacity(this.getGlowOpacity())
      Circle().width(200).height(200).fill(this.spirit.getGlowColor()).opacity(this.getGlowOpacity() * 0.5)
      Circle().width(160).height(160).fill('#FFFFFF').opacity(0.9)
      Image($r('app.media.startIcon')).width(150).height(150).objectFit(ImageFit.Cover)
        .clip(new Circle({ width: 150, height: 150 }))
      Circle().width(160).height(160).fill('#00000000')
        .stroke(this.spirit.getGlowColor()).strokeWidth(3)
      if (this.showFaceTag) {
        Text(this.faceTag).fontSize(28).fontColor('#FFFFFF')
          .position({ x: 105, y: 30 })
          .shadow({ radius: 4, color: '#00000080', offsetX: 1, offsetY: 1 })
      }
    }.scale({ x: this.spiritScale, y: this.spiritScale })
      .translate({ y: this.spiritOffsetY + this.jumpOffset })
      .rotate({ angle: this.wobbleAngle + this.tailAngle * 0.3, x: 0, y: 1, z: 0, centerX: '50%', centerY: '50%' })
  }

  @Builder
  ReactionBubble() {
    if (this.showReaction) {
      Column() {
        Text(this.reactionText).fontSize(15).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
      }.padding({ left: 14, right: 14, top: 8, bottom: 8 }).borderRadius(18)
        .backgroundColor('#FF6B6B')
        .shadow({ radius: 6, color: '#CC555580', offsetX: 0, offsetY: 3 })
        .translate({ y: -35 })
    }
  }

  @Builder
  SparkleEffect() {
    ForEach(this.sparkles, (item: number) => {
      Text('✨').fontSize(14 + item * 2).fontColor('#FFD700')
        .position({ x: 20 + (item % 4) * 70, y: 40 + Math.floor(item / 4) * 90 }).opacity(0.6)
    }, (item: number) => item.toString())
  }

  @Builder
  StatusBar(title: string, value: number, color: string, desc: string) {
    Row() {
      Text(title).fontSize(12).fontColor('#BBBBBB').width(45)
      Stack() {
        Row().width('100%').height(6).borderRadius(3).backgroundColor('#333333')
        Row().width(`${Math.max(2, value)}%`).height(6).borderRadius(3).backgroundColor(color)
      }.layoutWeight(1)
      Text(desc).fontSize(11).fontColor(color).fontWeight(FontWeight.Bold).width(60).textAlign(TextAlign.End)
    }.width('100%').height(16).alignItems(VerticalAlign.Center)
  }

  @Builder
  ActionBtn(icon: string, label: string, bgColor: string, onClick: () => void) {
    Column() {
      Text(icon).fontSize(22)
      Text(label).fontSize(11).fontColor('#BBBBBB').margin({ top: 2 })
    }.width(56).height(56).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .borderRadius(12).backgroundColor(bgColor)
      .shadow({ radius: 4, color: '#00000040', offsetX: 0, offsetY: 2 }).onClick(onClick)
  }

  @Builder
  TodoItemRow(item: TodoItem) {
    Row() {
      if (!item.completed) {
        Circle().width(20).height(20).fill('#00000000').stroke('#42A5F5').strokeWidth(2)
          .onClick(() => { this.onTodoComplete(item.id) })
      } else {
        Circle().width(20).height(20).fill('#4CAF50').stroke('#4CAF50').strokeWidth(2)
      }
      Text(item.title).fontSize(14).fontColor(item.completed ? '#666666' : '#CCCCCC')
        .margin({ left: 10 }).layoutWeight(1)
        .decoration({ type: item.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
      if (item.remindHour >= 0) {
        Text(`${item.remindHour}:${item.remindMinute < 10 ? '0' : ''}${item.remindMinute}`)
          .fontSize(12).fontColor('#FFA726').margin({ left: 6 })
      }
    }.width('100%').height(36).alignItems(VerticalAlign.Center).padding({ left: 8, right: 8 })
  }

  @Builder
  AlarmPanel() {
    if (this.showAlarmPanel) {
      Column() {
        Text('闹钟管理').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).margin({ bottom: 12 })
        if (this.alarmList.items.length > 0) {
          Text('已设置的闹钟').fontSize(13).fontColor('#42A5F5').margin({ bottom: 6 })
          ForEach(this.alarmList.items, (item: AlarmItem) => {
            Row() {
              Text(item.getTimeStr()).fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).layoutWeight(1)
              Text(item.label).fontSize(12).fontColor('#AAAAAA').layoutWeight(1)
              Button('取消').fontSize(12).fontColor('#FF4444').backgroundColor('#3A1A1A').borderRadius(6).height(28)
                .onClick(() => { this.cancelAlarm(item.eventId) })
            }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 4 })
          }, (item: AlarmItem) => item.eventId.toString())
        } else {
          Text('暂无闹钟').fontSize(13).fontColor('#888888').margin({ bottom: 6 })
        }
        Divider().color('#333333').margin({ top: 8, bottom: 8 })
        Text('设置新闹钟').fontSize(13).fontColor('#42A5F5').margin({ bottom: 6 })
        Row() {
          Column() {
            Text('时').fontSize(12).fontColor('#AAAAAA')
            Slider({ value: this.alarmHour, min: 0, max: 23, step: 1, style: SliderStyle.InSet })
              .width(150).trackColor('#333333').selectedColor('#42A5F5')
              .onChange((value: number) => { this.alarmHour = Math.round(value) })
            Text(`${this.alarmHour}时`).fontSize(14).fontColor('#42A5F5').fontWeight(FontWeight.Bold)
          }
          Column() {
            Text('分').fontSize(12).fontColor('#AAAAAA')
            Slider({ value: this.alarmMinute, min: 0, max: 59, step: 1, style: SliderStyle.InSet })
              .width(150).trackColor('#333333').selectedColor('#42A5F5')
              .onChange((value: number) => { this.alarmMinute = Math.round(value) })
            Text(`${this.alarmMinute}分`).fontSize(14).fontColor('#42A5F5').fontWeight(FontWeight.Bold)
          }
        }.justifyContent(FlexAlign.SpaceAround)
        Row() {
          Button('关闭').fontSize(14).fontColor('#AAAAAA').backgroundColor('#333333').borderRadius(8)
            .onClick(() => { this.showAlarmPanel = false })
          Button('设置闹钟').fontSize(14).fontColor('#FFFFFF').backgroundColor('#42A5F5').borderRadius(8)
            .onClick(() => { this.publishAlarmReminder() })
        }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 12 })
      }.width('90%').padding(16).borderRadius(16).backgroundColor('#1A1A2E')
        .shadow({ radius: 8, color: '#00000060', offsetX: 0, offsetY: 4 }).margin({ top: 8 })
    }
  }

  @Builder
  AddTodoPanel() {
    if (this.showAddTodoPanel) {
      Column() {
        Text('添加待办事项').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).margin({ bottom: 12 })
        TextInput({ placeholder: '输入待办内容...' }).width('100%').height(40).fontSize(14)
          .fontColor('#FFFFFF').placeholderColor('#666666').backgroundColor('#333333').borderRadius(8)
          .onChange((value: string) => { this.newTodoTitle = value })
        Row() {
          Button('取消').fontSize(14).fontColor('#AAAAAA').backgroundColor('#333333').borderRadius(8)
            .onClick(() => { this.showAddTodoPanel = false; this.newTodoTitle = '' })
          Button('添加').fontSize(14).fontColor('#FFFFFF').backgroundColor('#4CAF50').borderRadius(8)
            .onClick(() => { this.onAddTodo() })
        }.width('100%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 12 })
      }.width('90%').padding(16).borderRadius(16).backgroundColor('#1A1A2E')
        .shadow({ radius: 8, color: '#00000060', offsetX: 0, offsetY: 4 }).margin({ top: 8 })
    }
  }

  @Builder
  ChatPanel() {
    if (this.showChatPanel) {
      Column() {
        Row() {
          Text('对话灰灰').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).layoutWeight(1)
          Button('关闭').fontSize(12).fontColor('#AAAAAA').backgroundColor('#333333').borderRadius(8)
            .onClick(() => { this.showChatPanel = false })
        }.width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 8 })

        List() {
          if (this.chatMessages.length === 0) {
            ListItem() {
              Text('输入文字或点击录音开始对话~').fontSize(13).fontColor('#888888')
                .textAlign(TextAlign.Center).width('100%')
            }
          }
          ForEach(this.chatMessages, (msg: string) => {
            ListItem() {
              Row() {
                Text(msg).fontSize(14)
                  .fontColor(msg.startsWith('🐱') ? '#FFD700' : '#EEEEEE')
                  .padding(10).borderRadius(12)
                  .backgroundColor(msg.startsWith('🐱') ? '#1A1A0E' : '#2A2A3E')
                  .maxLines(5)
              }.width('88%').justifyContent(msg.startsWith('🐱') ? FlexAlign.End : FlexAlign.Start)
                .onClick(() => {
                  let pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, msg)
                  let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard()
                  systemPasteboard.setData(pasteData)
                  this.spirit.currentMessage = '已复制到剪贴板喵~'
                  this.spirit = this.spirit.copy()
                })
            }
          }, (msg: string, index: number) => msg + index.toString())
        }.width('100%').height(160).scrollBar(BarState.Auto).margin({ bottom: 8 })

        Row() {
          TextInput({ text: this.chatInput, placeholder: '说点什么...' })
            .type(InputType.Normal).layoutWeight(1).height(44).fontSize(15)
            .fontColor('#FFFFFF').placeholderColor('#666666').backgroundColor('#333333').borderRadius(10)
            .onChange((value: string) => { this.chatInput = value })
          Button('发送').height(44).fontSize(15).fontColor('#FFFFFF').backgroundColor('#4CAF50').borderRadius(10)
            .onClick(() => { this.sendChatMessage() })
        }.width('100%')

        Button(this.isRecording ? '● 录音中...松开结束' : '按住说话')
          .fontSize(15).fontColor(this.isRecording ? '#FF4444' : '#FFFFFF')
          .backgroundColor(this.isRecording ? '#3A1A1A' : '#1A2A3E')
          .borderRadius(10).width('100%').height(44).margin({ top: 8 })
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.startVoiceRecording()
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.stopVoiceRecording()
            }
          })
      }.width('90%').padding(16).borderRadius(16).backgroundColor('#1A1A2E')
        .shadow({ radius: 8, color: '#00000060', offsetX: 0, offsetY: 4 }).margin({ top: 8 })
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text(this.spirit.getMoodEmoji()).fontSize(20)
          Text(this.spirit.name).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ left: 6 })
          Text(this.spirit.getMissionBadge()).fontSize(12).fontColor(this.spirit.getGlowColor())
            .margin({ left: 8 }).padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .borderRadius(8).backgroundColor('#33333380')
          Button(this.use3D ? '3D' : '2D').fontSize(12).fontColor('#FFFFFF')
            .backgroundColor(this.use3D ? '#4CAF50' : '#42A5F5').borderRadius(8).margin({ left: 8 })
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => { this.toggle3D() })
          if (this.use3D) {
            Text(this.loadMsg).fontSize(9).fontColor('#4CAF50').margin({ left: 4 })
          }
        }.width('100%').justifyContent(FlexAlign.Center).padding({ top: 16, bottom: 4 })

        Stack() {
          if (this.use3D && this.sceneOpt != null) {
            Component3D(this.sceneOpt)
              .width('100%').height(280)
              .scale({ x: this.spiritScale, y: this.spiritScale })
              .translate({ y: this.jumpOffset })
          } else {
            this.CatAvatar()
          }
          this.ReactionBubble()
          if (!this.use3D) {
            this.SparkleEffect()
          }
          if (this.showFaceTag && this.use3D) {
            Text(this.faceTag).fontSize(36).fontColor('#FFFFFF')
              .position({ x: 130, y: 80 })
              .shadow({ radius: 6, color: '#00000080', offsetX: 2, offsetY: 2 })
          }
        }.width('100%').height(280)
        .gesture(
          PanGesture({ fingers: 1 })
            .onActionUpdate((event: GestureEvent) => {
              if (this.use3D && this.cam != null) {
                this.cam.position.x = event.offsetX * 0.008
                this.cam.position.y = 0.8 - event.offsetY * 0.008
              }
            })
        )

        Column() {
          Text(this.spirit.currentMessage).fontSize(14).fontColor('#CCCCCC')
            .textAlign(TextAlign.Center).maxLines(2)
        }.width('85%').padding(10).borderRadius(12).backgroundColor('#1A1A2E').margin({ top: 4 })

        Row() {
          this.ActionBtn('🍖', '喂食', '#2A1A0E', () => { this.doAction(() => this.spirit.onFeed(), '😋') })
          this.ActionBtn('🎾', '玩耍', '#1A2E1A', () => { this.doAction(() => this.spirit.onPlay(), '🤩') })
          this.ActionBtn('🤗', '抚摸', '#2E1A2A', () => { this.doAction(() => this.spirit.onTouch(), '❤️') })
          this.ActionBtn('🚶', '溜猫', '#1A3E2A', () => { this.doAction(() => this.spirit.onWalk(), '🎉') })
          this.ActionBtn('🛁', '洗澡', '#1A2A3E', () => { this.doAction(() => this.spirit.onBath(), '✨') })
          this.ActionBtn('👗', '装扮', '#2A2A1A', () => { this.doAction(() => this.spirit.onDress(), '👑') })
        }.width('90%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 8 }).padding(8).borderRadius(12)
          .backgroundColor('#1A1A2E')

Row() {
          this.ActionBtn('📋', '待办', '#1A3E2A', () => {
            this.showTodoList = !this.showTodoList; this.showAddTodoPanel = false; this.showAlarmPanel = false; this.showChatPanel = false
          })
          this.ActionBtn('➕', '新增', '#1A2E2A', () => {
            this.showAddTodoPanel = !this.showAddTodoPanel; this.showTodoList = false; this.showAlarmPanel = false; this.showChatPanel = false
          })
          this.ActionBtn('⏰', '闹钟', '#1A2A3E', () => {
            this.showAlarmPanel = !this.showAlarmPanel; this.showAddTodoPanel = false; this.showTodoList = false; this.showChatPanel = false
            if (this.showAlarmPanel) { this.refreshAlarmListFromCalendar() }
          })
          this.ActionBtn('💬', '对话', '#2A1A2A', () => {
            this.showChatPanel = !this.showChatPanel; this.showAlarmPanel = false; this.showAddTodoPanel = false; this.showTodoList = false
          })
          this.ActionBtn('💤', '休息', '#1A1A2E', () => { this.doAction(() => this.spirit.onRest(), '😴') })
        }.width('90%').justifyContent(FlexAlign.SpaceEvenly).margin({ top: 4 }).padding(4).borderRadius(10)
          .backgroundColor('#1A1A2E')

        this.AlarmPanel()
        this.AddTodoPanel()
        this.ChatPanel()

        if (this.showTodoList) {
          Column() {
            Text('待办事项').fontSize(16).fontColor('#FFFFFF').fontWeight(FontWeight.Bold).margin({ bottom: 8 })
            if (this.todoList.getPendingItems().length > 0) {
              Text('进行中').fontSize(12).fontColor('#42A5F5').margin({ bottom: 4 })
              ForEach(this.todoList.getPendingItems(), (item: TodoItem) => { this.TodoItemRow(item) },
                (item: TodoItem) => item.id.toString())
            }
            if (this.todoList.getCompletedItems().length > 0) {
              Text('已完成').fontSize(12).fontColor('#4CAF50').margin({ top: 8, bottom: 4 })
              ForEach(this.todoList.getCompletedItems(), (item: TodoItem) => { this.TodoItemRow(item) },
                (item: TodoItem) => item.id.toString())
            }
            Row() {
              Text(`完成 ${this.todoList.getCompletedCount()}/${this.todoList.items.length}`)
                .fontSize(12).fontColor('#AAAAAA')
            }.width('100%').justifyContent(FlexAlign.Center).margin({ top: 8 })
          }.width('90%').padding(12).borderRadius(12).backgroundColor('#1A1A2E').margin({ top: 8 })
        }

        Column() {
          this.StatusBar('饱腹', this.spirit.hunger, this.spirit.getStatusColor(this.spirit.hunger), this.spirit.getHungerDesc())
          this.StatusBar('快乐', this.spirit.happiness, this.spirit.getStatusColor(this.spirit.happiness), this.spirit.getHappinessDesc())
          this.StatusBar('能量', this.spirit.energy, this.spirit.getStatusColor(this.spirit.energy), this.spirit.getEnergyDesc())
          this.StatusBar('亲密度', this.spirit.affinity, '#AB47BC', this.spirit.getAffinityDesc())
        }.width('85%').margin({ top: 8 }).padding(10).borderRadius(12).backgroundColor('#1A1A2E')

        Text('v1.1.0 | 拖拽旋转 | 你的专属空间管家灰灰')
          .fontSize(11).fontColor('#555555').margin({ top: 8, bottom: 16 }).textAlign(TextAlign.Center)
      }.width('100%').alignItems(HorizontalAlign.Center)
    }.width('100%').height('100%').scrollBar(BarState.Off)
    .linearGradient({
      direction: GradientDirection.Bottom,
      colors: [['#0D0D1A', 0.0], ['#1A1A2E', 0.3], ['#16213E', 0.7], ['#0F3460', 1.0]]
    })
  }
}