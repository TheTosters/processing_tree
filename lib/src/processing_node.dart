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
