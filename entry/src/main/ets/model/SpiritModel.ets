export enum SpiritMood {
  HAPPY = '开心',
  NORMAL = '平静',
  CONCERNED = '关切',
  EXCITED = '兴奋',
  WORRIED = '担忧',
  PROUD = '自豪'
}

export enum SpiritMission {
  IDLE = 'idle',
  WAKE_UP = 'wake_up',
  REMIND = 'remind',
  CHEER = 'cheer',
  GREET = 'greet',
  WALK = 'walk',
  BATH = 'bath',
  DRESS = 'dress'
}

export class SpiritState {
  name: string = '灰灰'
  mood: SpiritMood = SpiritMood.NORMAL
  mission: SpiritMission = SpiritMission.IDLE
  energy: number = 80
  happiness: number = 80
  hunger: number = 80
  affinity: number = 10
  taskCount: number = 0
  completedCount: number = 0
  currentMessage: string = '你好！我是你的精灵管家灰灰~'

  onFeed(): string {
    this.hunger = Math.min(100, this.hunger + 20)
    this.happiness = Math.min(100, this.happiness + 10)
    this.energy = Math.min(100, this.energy + 5)
    this.affinity = Math.min(100, this.affinity + 2)
    this.mission = SpiritMission.CHEER
    this.updateMood()
    this.currentMessage = '好吃好吃！谢谢你~'
    return this.currentMessage
  }

  onPlay(): string {
    this.happiness = Math.min(100, this.happiness + 25)
    this.hunger = Math.max(0, this.hunger - 10)
    this.energy = Math.max(0, this.energy - 15)
    this.affinity = Math.min(100, this.affinity + 4)
    this.mission = SpiritMission.CHEER
    this.updateMood()
    this.currentMessage = '好玩好玩！一起玩！'
    return this.currentMessage
  }

  onTouch(): string {
    this.happiness = Math.min(100, this.happiness + 10)
    this.affinity = Math.min(100, this.affinity + 3)
    this.mission = SpiritMission.GREET
    this.updateMood()
    this.currentMessage = '嘿嘿，被摸到了~好舒服'
    return this.currentMessage
  }

  onRest(): string {
    this.energy = Math.min(100, this.energy + 30)
    this.hunger = Math.max(0, this.hunger - 5)
    this.happiness = Math.max(0, this.happiness - 5)
    this.mission = SpiritMission.IDLE
    this.updateMood()
    this.currentMessage = '我休息一下，随时待命...'
    return this.currentMessage
  }

  onWalk(): string {
    this.happiness = Math.min(100, this.happiness + 30)
    this.hunger = Math.max(0, this.hunger - 15)
    this.energy = Math.max(0, this.energy - 20)
    this.affinity = Math.min(100, this.affinity + 5)
    this.mission = SpiritMission.WALK
    this.updateMood()
    this.currentMessage = '外面好好玩！溜溜溜~'
    return this.currentMessage
  }

  onBath(): string {
    this.happiness = Math.min(100, this.happiness + 15)
    this.energy = Math.max(0, this.energy - 10)
    this.affinity = Math.min(100, this.affinity + 3)
    this.mission = SpiritMission.BATH
    this.updateMood()
    this.currentMessage = '洗香香了~好舒服！'
    return this.currentMessage
  }

  onDress(): string {
    this.happiness = Math.min(100, this.happiness + 20)
    this.affinity = Math.min(100, this.affinity + 4)
    this.mission = SpiritMission.DRESS
    this.updateMood()
    this.currentMessage = '换上新衣服啦！好看吗？'
    return this.currentMessage
  }

  onTaskAdded(): void {
    this.taskCount++
    this.happiness = Math.min(100, this.happiness + 5)
    this.affinity = Math.min(100, this.affinity + 2)
    this.updateMood()
  }

  onTaskCompleted(): string {
    this.completedCount++
    this.happiness = Math.min(100, this.happiness + 15)
    this.affinity = Math.min(100, this.affinity + 5)
    this.energy = Math.max(0, this.energy - 3)
    this.updateMood()
    return this.onMissionChange(SpiritMission.CHEER)
  }

  onMissionChange(mission: SpiritMission): string {
    this.mission = mission
    this.updateMood()
    this.currentMessage = this.getMessageForMission(mission)
    return this.currentMessage
  }

  getMessageForMission(mission: SpiritMission): string {
    if (mission === SpiritMission.WAKE_UP) {
      return '该起床啦！新的一天开始了！'
    } else if (mission === SpiritMission.REMIND) {
      return '别忘了你的待办事项哦！'
    } else if (mission === SpiritMission.CHEER) {
      return '太棒了！又完成一个任务！'
    } else if (mission === SpiritMission.GREET) {
      return '早上好！今天有什么计划？'
    } else if (mission === SpiritMission.WALK) {
      return '外面好好玩！溜溜溜~'
    } else if (mission === SpiritMission.BATH) {
      return '洗香香了~好舒服！'
    } else if (mission === SpiritMission.DRESS) {
      return '换上新衣服啦！好看吗？'
    } else {
      return '我在这里陪你~有什么需要帮忙的吗？'
    }
  }

  decay(): void {
    this.energy = Math.max(0, this.energy - 2)
    this.happiness = Math.max(0, this.happiness - 1)
    this.hunger = Math.max(0, this.hunger - 2)
    this.updateMood()
  }

  updateMood(): void {
    if (this.hunger < 30) {
      this.mood = SpiritMood.WORRIED
    } else if (this.completedCount >= 3) {
      this.mood = SpiritMood.PROUD
    } else if (this.taskCount >= 5 && this.completedCount < 2) {
      this.mood = SpiritMood.WORRIED
    } else if (this.mission === SpiritMission.WAKE_UP) {
      this.mood = SpiritMood.CONCERNED
    } else if (this.mission === SpiritMission.CHEER) {
      this.mood = SpiritMood.EXCITED
    } else if (this.happiness > 70) {
      this.mood = SpiritMood.HAPPY
    } else {
      this.mood = SpiritMood.NORMAL
    }
  }

  getMoodEmoji(): string {
    if (this.mood === SpiritMood.HAPPY) {
      return '😊'
    } else if (this.mood === SpiritMood.EXCITED) {
      return '🤩'
    } else if (this.mood === SpiritMood.CONCERNED) {
      return '🧐'
    } else if (this.mood === SpiritMood.WORRIED) {
      return '😟'
    } else if (this.mood === SpiritMood.PROUD) {
      return '😎'
    } else {
      return '🙂'
    }
  }

  getMissionBadge(): string {
    if (this.mission === SpiritMission.WAKE_UP) {
      return '⏰ 起床提醒'
    } else if (this.mission === SpiritMission.REMIND) {
      return '📋 待办提醒'
    } else if (this.mission === SpiritMission.CHEER) {
      return '🎉 任务完成'
    } else if (this.mission === SpiritMission.GREET) {
      return '☀️ 问候'
    } else if (this.mission === SpiritMission.WALK) {
      return '🚶 溜猫中'
    } else if (this.mission === SpiritMission.BATH) {
      return '🛁 洗澡中'
    } else if (this.mission === SpiritMission.DRESS) {
      return '👗 装扮中'
    } else {
      return '💫 待命中'
    }
  }

  getGlowColor(): string {
    if (this.mood === SpiritMood.EXCITED) {
      return '#FFD700'
    } else if (this.mood === SpiritMood.HAPPY) {
      return '#66BB6A'
    } else if (this.mood === SpiritMood.CONCERNED) {
      return '#FFA726'
    } else if (this.mood === SpiritMood.WORRIED) {
      return '#EF5350'
    } else if (this.mood === SpiritMood.PROUD) {
      return '#AB47BC'
    } else {
      return '#42A5F5'
    }
  }

  getStatusColor(value: number): string {
    if (value > 60) {
      return '#4CAF50'
    } else if (value > 30) {
      return '#FFC107'
    } else {
      return '#F44336'
    }
  }

  getHungerDesc(): string {
    if (this.hunger > 80) { return '饱饱的~' }
    else if (this.hunger > 60) { return '还行不饿' }
    else if (this.hunger > 40) { return '有点饿了' }
    else if (this.hunger > 20) { return '饿坏了！' }
    else { return '快饿晕了！！' }
  }

  getHappinessDesc(): string {
    if (this.happiness > 80) { return '超开心！' }
    else if (this.happiness > 60) { return '心情不错' }
    else if (this.happiness > 40) { return '还行吧...' }
    else if (this.happiness > 20) { return '有点无聊' }
    else { return '很沮丧...' }
  }

  getEnergyDesc(): string {
    if (this.energy > 80) { return '精力充沛！' }
    else if (this.energy > 60) { return '状态不错' }
    else if (this.energy > 40) { return '有点累了' }
    else if (this.energy > 20) { return '好困...' }
    else { return '累瘫了！！' }
  }

  getAffinityDesc(): string {
    if (this.affinity > 80) { return '亲密无间！' }
    else if (this.affinity > 60) { return '关系不错' }
    else if (this.affinity > 40) { return '渐渐熟悉' }
    else if (this.affinity > 20) { return '还在了解' }
    else { return '刚认识呢~' }
  }

  copy(): SpiritState {
    let s = new SpiritState()
    s.name = this.name
    s.mood = this.mood
    s.mission = this.mission
    s.energy = this.energy
    s.happiness = this.happiness
    s.affinity = this.affinity
    s.taskCount = this.taskCount
    s.hunger = this.hunger
    s.taskCount = this.taskCount
    s.completedCount = this.completedCount
    s.currentMessage = this.currentMessage
    return s
  }
}