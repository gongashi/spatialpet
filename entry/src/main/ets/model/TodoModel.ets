export class TodoItem {
  id: number = 0
  title: string = ''
  completed: boolean = false
  priority: number = 0
  remindHour: number = -1
  remindMinute: number = -1

  copy(): TodoItem {
    let item = new TodoItem()
    item.id = this.id
    item.title = this.title
    item.completed = this.completed
    item.priority = this.priority
    item.remindHour = this.remindHour
    item.remindMinute = this.remindMinute
    return item
  }
}

export class TodoList {
  items: TodoItem[] = []
  nextId: number = 1

  addItem(title: string, priority: number = 0, remindHour: number = -1, remindMinute: number = -1): TodoItem {
    let item = new TodoItem()
    item.id = this.nextId
    item.title = title
    item.priority = priority
    item.remindHour = remindHour
    item.remindMinute = remindMinute
    this.nextId++
    this.items.push(item)
    return item
  }

  completeItem(id: number): void {
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].id === id) {
        this.items[i].completed = true
        break
      }
    }
  }

  removeItem(id: number): void {
    this.items = this.items.filter((item: TodoItem) => item.id !== id)
  }

  getPendingItems(): TodoItem[] {
    return this.items.filter((item: TodoItem) => !item.completed)
  }

  getCompletedItems(): TodoItem[] {
    return this.items.filter((item: TodoItem) => item.completed)
  }

  getPendingCount(): number {
    return this.getPendingItems().length
  }

  getCompletedCount(): number {
    return this.getCompletedItems().length
  }

  checkReminders(currentHour: number, currentMinute: number): TodoItem[] {
    let dueItems: TodoItem[] = []
    for (let i = 0; i < this.items.length; i++) {
      let item = this.items[i]
      if (!item.completed && item.remindHour === currentHour && item.remindMinute === currentMinute) {
        dueItems.push(item)
      }
    }
    return dueItems
  }

  copy(): TodoList {
    let newList = new TodoList()
    newList.nextId = this.nextId
    newList.items = this.items.map((item: TodoItem) => item.copy())
    return newList
  }
}