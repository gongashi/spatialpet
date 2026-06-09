import { calendarManager } from '@kit.CalendarKit'
import { common } from '@kit.AbilityKit'
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { hilog } from '@kit.PerformanceAnalysisKit'

const TAG: string = 'AlarmModel'
const DOMAIN: number = 0xFF00

export class AlarmItem {
  eventId: number = 0
  hour: number = 0
  minute: number = 0
  label: string = ''

  constructor(eventId: number, hour: number, minute: number, label: string) {
    this.eventId = eventId
    this.hour = hour
    this.minute = minute
    this.label = label
  }

  getTimeStr(): string {
    return this.hour + ':' + (this.minute < 10 ? '0' : '') + this.minute
  }

  copy(): AlarmItem {
    return new AlarmItem(this.eventId, this.hour, this.minute, this.label)
  }
}

export class AlarmList {
  items: AlarmItem[] = []

  add(item: AlarmItem): void {
    this.items.push(item)
  }

  remove(eventId: number): void {
    this.items = this.items.filter((item: AlarmItem) => item.eventId !== eventId)
  }

  copy(): AlarmList {
    let newList: AlarmList = new AlarmList()
    newList.items = this.items.map((item: AlarmItem) => item.copy())
    return newList
  }
}

export class CalendarAlarmService {
  private calendar: calendarManager.Calendar | undefined = undefined
  private calendarMgr: calendarManager.CalendarManager | null = null
  private calendarAccount: calendarManager.CalendarAccount = {
    name: 'SpatialPetAlarm',
    type: calendarManager.CalendarType.LOCAL,
    displayName: '灰灰闹钟'
  }

  async initCalendar(context: common.UIAbilityContext): Promise<boolean> {
    try {
      let atManager = abilityAccessCtrl.createAtManager()
      let permissions: Permissions[] = ['ohos.permission.READ_CALENDAR', 'ohos.permission.WRITE_CALENDAR']
      let result = await atManager.requestPermissionsFromUser(context, permissions)
      let isPermitted: boolean = true
      for (let i: number = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== 0) {
          isPermitted = false
          break
        }
      }
      if (!isPermitted) {
        hilog.error(DOMAIN, TAG, 'Calendar permissions denied')
        return false
      }
      this.calendarMgr = calendarManager.getCalendarManager(context)
      this.calendar = await this.calendarMgr.createCalendar(this.calendarAccount)
      let config: calendarManager.CalendarConfig = { enableReminder: true, color: '#42A5F5' }
      await this.calendar.setConfig(config)
      hilog.info(DOMAIN, TAG, 'Calendar initialized successfully')
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'initCalendar failed: %{public}s', JSON.stringify(e))
      return false
    }
  }

  async addAlarm(hour: number, minute: number, label: string): Promise<AlarmItem | null> {
    if (this.calendar === undefined) {
      hilog.error(DOMAIN, TAG, 'Calendar not initialized')
      return null
    }
    try {
      let now: Date = new Date()
      let alarmDate: Date = new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0)
      if (alarmDate.getTime() <= now.getTime()) {
        alarmDate.setDate(alarmDate.getDate() + 1)
      }
      let event: calendarManager.Event = {
        type: calendarManager.EventType.NORMAL,
        title: '灰灰提醒你 - ' + label,
        startTime: alarmDate.getTime(),
        endTime: alarmDate.getTime() + 60 * 1000,
        reminderTime: [0],
        description: hour + ':' + (minute < 10 ? '0' : '') + minute + ' 的提醒到了喵！'
      }
      let eventId: number = await this.calendar.addEvent(event)
      hilog.info(DOMAIN, TAG, 'Alarm event added, id: %{public}d', eventId)
      return new AlarmItem(eventId, hour, minute, label)
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'addAlarm failed: %{public}s', JSON.stringify(e))
      return null
    }
  }

  async removeAlarm(eventId: number): Promise<boolean> {
    if (this.calendar === undefined) {
      return false
    }
    try {
      await this.calendar.deleteEvent(eventId)
      hilog.info(DOMAIN, TAG, 'Alarm event deleted, id: %{public}d', eventId)
      return true
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'removeAlarm failed: %{public}s', JSON.stringify(e))
      return false
    }
  }

  async getAlarmList(): Promise<AlarmList> {
    if (this.calendar === undefined) {
      return new AlarmList()
    }
    try {
      let filter: calendarManager.EventFilter = calendarManager.EventFilter.filterByTitle('灰灰提醒你')
      let events: calendarManager.Event[] = await this.calendar.getEvents(filter)
      let alarmList: AlarmList = new AlarmList()
      for (let ev of events) {
        let startDate: Date = new Date(ev.startTime)
        alarmList.add(new AlarmItem(ev.id ?? 0, startDate.getHours(), startDate.getMinutes(), '闹钟'))
      }
      return alarmList
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'getAlarmList failed: %{public}s', JSON.stringify(e))
      return new AlarmList()
    }
  }

  async clearAllAlarms(): Promise<number> {
    if (this.calendar === undefined) {
      return 0
    }
    try {
      let filter: calendarManager.EventFilter = calendarManager.EventFilter.filterByTitle('灰灰提醒你')
      let events: calendarManager.Event[] = await this.calendar.getEvents(filter)
      let ids: number[] = []
      for (let ev of events) {
        if (ev.id !== undefined) {
          ids.push(ev.id)
        }
      }
      if (ids.length > 0) {
        await this.calendar.deleteEvents(ids)
      }
      hilog.info(DOMAIN, TAG, 'clearAllAlarms: cleared %{public}d events', ids.length)
      return ids.length
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'clearAllAlarms failed: %{public}s', JSON.stringify(e))
      return 0
    }
  }
}