import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const TodoApp());
}

class TodoApp extends StatelessWidget {
  const TodoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do List',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TodoHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key});

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage>
    with TickerProviderStateMixin {
  // List to store all tasks
  List<Task> tasks = [];

  // Text controller for input field
  final TextEditingController _taskController = TextEditingController();

  // Text controller for edit dialog
  final TextEditingController _editController = TextEditingController();

  // Focus node for input field
  final FocusNode _focusNode = FocusNode();

  // Animation controller for task additions
  late AnimationController _animationController;

  // Current selected priority for new tasks
  TaskPriority _selectedPriority = TaskPriority.medium;

  // Sort option
  SortOption _currentSort = SortOption.dateCreated;

  @override
  void initState() {
    super.initState();
    _loadTasks(); // Load saved tasks when app starts
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    _editController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Load tasks from SharedPreferences (persistence)
  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? tasksJson = prefs.getString('tasks');

      if (tasksJson != null) {
        final List<dynamic> tasksList = json.decode(tasksJson);
        setState(() {
          tasks = tasksList.map((task) => Task.fromJson(task)).toList();
        });
      }
    } catch (e) {
      // Handle error loading tasks
      debugPrint('Error loading tasks: $e');
    }
  }

  /// Save tasks to SharedPreferences (persistence)
  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String tasksJson = json.encode(
        tasks.map((task) => task.toJson()).toList(),
      );
      await prefs.setString('tasks', tasksJson);
    } catch (e) {
      // Handle error saving tasks
      debugPrint('Error saving tasks: $e');
    }
  }

  /// Add a new task to the list
  void _addTask() {
    final String taskText = _taskController.text.trim();

    if (taskText.isNotEmpty) {
      setState(() {
        tasks.add(
          Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: taskText,
            isCompleted: false,
            createdAt: DateTime.now(),
            priority: _selectedPriority,
          ),
        );
        _sortTasks();
      });

      // Clear input field and reset priority
      _taskController.clear();
      _selectedPriority = TaskPriority.medium;
      _saveTasks();

      // Trigger animation
      _animationController.forward().then((_) {
        _animationController.reset();
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Task added successfully!'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Toggle task completion status
  void _toggleTask(int index) {
    setState(() {
      tasks[index].isCompleted = !tasks[index].isCompleted;
    });
    _saveTasks();
  }

  /// Delete a task from the list
  void _deleteTask(int index) {
    final String taskTitle = tasks[index].title;

    setState(() {
      tasks.removeAt(index);
    });
    _saveTasks();

    // Show deletion confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$taskTitle" deleted'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show confirmation dialog for task deletion
  void _showDeleteConfirmation(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Task'),
          content: Text(
            'Are you sure you want to delete "${tasks[index].title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTask(index);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  /// Edit an existing task
  void _editTask(int index) {
    _editController.text = tasks[index].title;
    TaskPriority editPriority = tasks[index].priority;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Task'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _editController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TaskPriority>(
                    value: editPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: TaskPriority.values.map((priority) {
                      return DropdownMenuItem(
                        value: priority,
                        child: Row(
                          children: [
                            Icon(
                              priority.icon,
                              color: priority.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(priority.displayName),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        editPriority = value!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newTitle = _editController.text.trim();
                    if (newTitle.isNotEmpty) {
                      setState(() {
                        tasks[index].title = newTitle;
                        tasks[index].priority = editPriority;
                        _sortTasks();
                      });
                      _saveTasks();
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Task updated successfully!'),
                          backgroundColor: Colors.blue,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Sort tasks based on current sort option
  void _sortTasks() {
    switch (_currentSort) {
      case SortOption.dateCreated:
        tasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOption.priority:
        tasks.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return b.priority.index.compareTo(a.priority.index);
        });
        break;
      case SortOption.alphabetical:
        tasks.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
  }

  /// Show sort options dialog
  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sort Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: SortOption.values.map((option) {
              return RadioListTile<SortOption>(
                title: Text(option.displayName),
                subtitle: Text(option.description),
                value: option,
                groupValue: _currentSort,
                onChanged: (value) {
                  setState(() {
                    _currentSort = value!;
                    _sortTasks();
                  });
                  _saveTasks();
                  Navigator.of(context).pop();
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          // Sort button
          if (tasks.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: _showSortOptions,
              tooltip: 'Sort tasks',
            ),
          // Menu button for additional options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_completed':
                  _clearCompletedTasks();
                  break;
                case 'clear_all':
                  _clearAllTasks();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'clear_completed',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear Completed'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Tasks'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Task input section with priority selector
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Text input field
                    Expanded(
                      child: TextField(
                        controller: _taskController,
                        focusNode: _focusNode,
                        decoration: const InputDecoration(
                          hintText: 'Enter a new task...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.0,
                            vertical: 8.0,
                          ),
                        ),
                        onSubmitted: (_) => _addTask(), // Add task on Enter key
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    // Add task button
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_animationController.value * 0.1),
                          child: ElevatedButton(
                            onPressed: _addTask,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20.0,
                                vertical: 12.0,
                              ),
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Add'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                // Priority selector
                Row(
                  children: [
                    const Text(
                      'Priority: ',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Expanded(
                      child: SegmentedButton<TaskPriority>(
                        segments: TaskPriority.values.map((priority) {
                          return ButtonSegment<TaskPriority>(
                            value: priority,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  priority.icon,
                                  size: 16,
                                  color: priority.color,
                                ),
                                const SizedBox(width: 4),
                                Text(priority.displayName),
                              ],
                            ),
                          );
                        }).toList(),
                        selected: {_selectedPriority},
                        onSelectionChanged: (Set<TaskPriority> selection) {
                          setState(() {
                            _selectedPriority = selection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Task statistics
          if (tasks.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Tasks',
                    tasks.length.toString(),
                    Colors.blue,
                  ),
                  _buildStatItem(
                    'Completed',
                    tasks.where((task) => task.isCompleted).length.toString(),
                    Colors.green,
                  ),
                  _buildStatItem(
                    'Pending',
                    tasks.where((task) => !task.isCompleted).length.toString(),
                    Colors.orange,
                  ),
                ],
              ),
            ),

          // Tasks list
          Expanded(
            child: tasks.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      return _buildTaskItem(index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// Build statistics item widget
  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  /// Build empty state widget when no tasks exist
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No tasks yet!',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a task to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  /// Build individual task item widget with animations
  Widget _buildTaskItem(int index) {
    final task = tasks[index];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Card(
        elevation: task.isCompleted ? 1 : 3,
        color: task.isCompleted ? Colors.grey[100] : null,
        child: ListTile(
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: Checkbox(
              value: task.isCompleted,
              onChanged: (_) => _toggleTask(index),
              activeColor: Colors.green,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    decoration: task.isCompleted
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: task.isCompleted ? Colors.grey[600] : Colors.black,
                    fontWeight: task.priority == TaskPriority.high
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
              // Priority indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: task.priority.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: task.priority.color.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      task.priority.icon,
                      size: 14,
                      color: task.priority.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.priority.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.priority.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created: ${_formatDate(task.createdAt)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editTask(index),
                tooltip: 'Edit task',
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _showDeleteConfirmation(index),
                tooltip: 'Delete task',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clear all completed tasks
  void _clearCompletedTasks() {
    final completedCount = tasks.where((task) => task.isCompleted).length;

    if (completedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No completed tasks to clear'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear Completed Tasks'),
          content: Text(
            'Are you sure you want to clear $completedCount completed task(s)?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  tasks.removeWhere((task) => task.isCompleted);
                });
                _saveTasks();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$completedCount completed task(s) cleared'),
                    backgroundColor: Colors.orange,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  /// Clear all tasks
  void _clearAllTasks() {
    if (tasks.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Clear All Tasks'),
          content: Text(
            'Are you sure you want to delete all ${tasks.length} task(s)? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final count = tasks.length;
                setState(() {
                  tasks.clear();
                });
                _saveTasks();
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All $count task(s) cleared'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );
  }

  /// Format date for display
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Sort options enumeration
enum SortOption { dateCreated, priority, alphabetical }

/// Extension to get sort option display properties
extension SortOptionExtension on SortOption {
  String get displayName {
    switch (this) {
      case SortOption.dateCreated:
        return 'Date Created';
      case SortOption.priority:
        return 'Priority';
      case SortOption.alphabetical:
        return 'Alphabetical';
    }
  }

  String get description {
    switch (this) {
      case SortOption.dateCreated:
        return 'Sort by creation date (newest first)';
      case SortOption.priority:
        return 'Sort by priority (high to low)';
      case SortOption.alphabetical:
        return 'Sort alphabetically (A to Z)';
    }
  }
}

/// Task model class with priority support
class Task {
  String id;
  String title;
  bool isCompleted;
  DateTime createdAt;
  TaskPriority priority;

  Task({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    this.priority = TaskPriority.medium,
  });

  /// Convert Task to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
      'priority': priority.index,
    };
  }

  /// Create Task from JSON for persistence
  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      isCompleted: json['isCompleted'],
      createdAt: DateTime.parse(json['createdAt']),
      priority: TaskPriority.values[json['priority'] ?? 1],
    );
  }
}

/// Task priority enumeration
enum TaskPriority { low, medium, high }

/// Extension to get priority display properties
extension TaskPriorityExtension on TaskPriority {
  String get displayName {
    switch (this) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TaskPriority.low:
        return Colors.green;
      case TaskPriority.medium:
        return Colors.orange;
      case TaskPriority.high:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (this) {
      case TaskPriority.low:
        return Icons.keyboard_arrow_down;
      case TaskPriority.medium:
        return Icons.remove;
      case TaskPriority.high:
        return Icons.keyboard_arrow_up;
    }
  }
}
