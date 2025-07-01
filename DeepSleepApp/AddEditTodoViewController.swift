import UIKit

protocol AddEditTodoDelegate: AnyObject {
    func didSaveTodoItem(_ todoItem: TodoItem)
}

class AddEditTodoViewController: UIViewController {
    weak var delegate: AddEditTodoDelegate?
    var todoItem: TodoItem?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = todoItem == nil ? "Add Todo" : "Edit Todo"
        // Setup UI for adding/editing a todo item
    }
} 
