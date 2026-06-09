export enum PetMood {
  HAPPY = '开心',
  NORMAL = '平静',
  HUNGRY = '饿了',
  TIRED = '困了',
  EXCITED = '兴奋',
  SAD = '不开心'
}

export enum PetAction {
  FEED = 'feed',
  PLAY = 'play',
  TOUCH = 'touch',
  REST = 'rest'
}

export class PetState {
  name: string = '萌宠'
  hunger: number = 80
  happiness: number = 80
  energy: number = 80
  mood: PetMood = PetMood.NORMAL
  lastAction: string = ''
  actionCount: number = 0

  updateMood(): void {
    if (this.hunger < 30) {
      this.mood = PetMood.HUNGRY
    } else if (this.energy < 30) {
      this.mood = PetMood.TIRED
    } else if (this.happiness > 90 && this.hunger > 60) {
      this.mood = PetMood.EXCITED
    } else if (this.happiness > 70) {
      this.mood = PetMood.HAPPY
    } else if (this.happiness < 40) {
      this.mood = PetMood.SAD
    } else {
      this.mood = PetMood.NORMAL
    }
  }

  doAction(action: PetAction): string {
    this.lastAction = action
    this.actionCount++
    let reaction: string = ''
    switch (action) {
      case PetAction.FEED:
        this.hunger = Math.min(100, this.hunger + 20)
        this.happiness = Math.min(100, this.happiness + 10)
        this.energy = Math.min(100, this.energy + 5)
        reaction = '好吃好吃！'
        break
      case PetAction.PLAY:
        this.happiness = Math.min(100, this.happiness + 25)
        this.hunger = Math.max(0, this.hunger - 10)
        this.energy = Math.max(0, this.energy - 15)
        reaction = '好玩好玩！'
        break
      case PetAction.TOUCH:
        this.happiness = Math.min(100, this.happiness + 15)
        this.energy = Math.max(0, this.energy - 5)
        reaction = '好舒服~'
        break
      case PetAction.REST:
        this.energy = Math.min(100, this.energy + 30)
        this.hunger = Math.max(0, this.hunger - 5)
        reaction = '睡个好觉...'
        break
    }
    this.updateMood()
    this.decay()
    return reaction
  }

  decay(): void {
    this.hunger = Math.max(0, this.hunger - 3)
    this.happiness = Math.max(0, this.happiness - 2)
    this.energy = Math.max(0, this.energy - 2)
    this.updateMood()
  }

  getMoodEmoji(): string {
    switch (this.mood) {
      case PetMood.HAPPY:
        return '😊'
      case PetMood.EXCITED:
        return '🤩'
      case PetMood.HUNGRY:
        return '🍽️'
      case PetMood.TIRED:
        return '😴'
      case PetMood.SAD:
        return '😢'
      default:
        return '🙂'
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

  copy(): PetState {
    let newPet = new PetState()
    newPet.name = this.name
    newPet.hunger = this.hunger
    newPet.happiness = this.happiness
    newPet.energy = this.energy
    newPet.mood = this.mood
    newPet.lastAction = this.lastAction
    newPet.actionCount = this.actionCount
    return newPet
  }
}