library processing_tree;

/// Informs caller of next action which should take place after processing
/// current node
enum Action {
  /// Next item from execution stack should be executed. If no more items then
  /// execution should finish
  proceed,

  /// Last executed item should be executed again
  repeat,

  /// Add marker to last executed item, and then proceed in the same way as
  /// [Action.proceed]. This has meaning only if there are children to execute
  markAndProceed,

  /// Instead of executing next item in stack, execution should be moved
  /// backward in stack to first item with mark (see [Action.markAndProceed])
  backToMark,

  /// Stop execution of children in this branch. (Items in call stack which are
  /// after last executed item are discarded, then first item from stack will be
  /// next one to execute)
  terminateBranch,

  /// Terminate whole execution, all items from stack are removed.
  terminate
}

/// Defines a signature of external function used in processing tree
///
/// Describes function which builds processing tree. Argument [context] refers
/// to object passed to [TreeProcessor.process] as an argument, it's passed
/// to all nodes when they are executed, and should be used to store state of
/// execution (values, results, etc.). Second argument [data] is an object added
/// to execution node at moment of creation node. It should be considered as
/// private data (constant if possible) needed by execution node. As a result
/// of processing action telling what should be done in next step is returned.
typedef PNDelegate = Action Function(dynamic context, dynamic data);

/// Private container which builds processing tree
///
/// Executable container which binds together info about next items to execute
/// arguments ([data]) needed for this execution and [delegate] which will be
/// executed when this node be processed.
class ProcessingNode {
  final List<ProcessingNode> children;
  final PNDelegate delegate;
  final dynamic data;
  bool mark = false;

  ProcessingNode(this.delegate, this.children, this.data);
}

/// Private execution controller for processing tree
///
/// Class responsible for perform execution of nodes in tree. It controls
/// passing needed data and handling [Action] returned by executed node.
class ProcessingContext {
  final List<ProcessingNode> _callStack = [];

  void process(ProcessingNode rootNode, dynamic extContext) {
    rootNode.mark = false;
    _callStack.add(rootNode);
    while (_callStack.isNotEmpty) {
      final toExecute = _callStack.removeLast();

      toExecute.mark = false; //Always reset mark before execution
      late Action nextAction;
      do {
        nextAction = toExecute.delegate(extContext, toExecute.data);
      } while (nextAction == Action.repeat);

      _handleNextAction(nextAction, toExecute);
    }
  }

  void reset() {
    _callStack.clear();
  }

  void _handleNextAction(Action nextAction, ProcessingNode lastExecuted) {
    switch (nextAction) {
      case Action.proceed:
        _callStack.addAll(lastExecuted.children.reversed);
        break;

      case Action.markAndProceed:
        //Mark has only meaning when it has children, otherwise no one can
        //return to marked place
        if (lastExecuted.children.isNotEmpty) {
          lastExecuted.mark = true;
          _callStack.add(lastExecuted);
          _callStack.addAll(lastExecuted.children.reversed);
        }
        break;

      case Action.repeat:
        assert(false, "How we get here?!");
        break;

      case Action.backToMark:
        _removeUntilFirstMark();
        break;

      case Action.terminateBranch:
        //We stop this execution branch here, don't process children
        break;

      case Action.terminate:
        //Whole tree execution should be stopped, just wipe out callstack
        _callStack.clear();
        break;
    }
  }

  /// NOTE: This might throw Exception if [_callstack] goes dry. This is
  /// expected because this mean that processing tree is malformed. If any node
  /// wants back to mark, then it must be sure that mark is already placed
  void _removeUntilFirstMark() {
    ProcessingNode node = _callStack.removeLast();
    while (!node.mark) {
      node = _callStack.removeLast();
    }
    _callStack.add(node); //return back marked node to stack
  }
}
