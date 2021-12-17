import 'package:processing_tree/src/processing_node.dart';

/// Interface which allows execution of processing tree.
abstract class TreeProcessor {
  /// Returns processor which performs tree in inverted order.
  TreeProcessor inverted();

  /// Performs execution of ready processing tree
  ///
  /// Input data needed by tree should be passed in [context] argument. Result
  /// of execution should be also stored in [context] if there is any result.
  /// Note: This function might throw exception if user functions build into
  /// tree throws exception. If processing tree is not malformed then processing
  /// tree library will not throw exception from this function.
  void process(dynamic context);
}

/// Implementation of [TreeProcessor] interface.
///
/// Implementation should be not directly visible for end user.
class TreeProcessorImpl extends TreeProcessor {
  final ProcessingNode root;
  final ProcessingContext ctx = ProcessingContext();
  TreeProcessorImpl(this.root);

  @override
  void process(dynamic context) {
    ctx.reset();
    ctx.process(root, context);
  }

  @override
  TreeProcessor inverted() {
    return TreeProcessorInvertedImpl(root);
  }
}

class TreeProcessorInvertedImpl extends TreeProcessor {
  final ProcessingNode root;
  final InvertedProcessingContext ctx = InvertedProcessingContext();
  TreeProcessorInvertedImpl(this.root);

  @override
  void process(dynamic context) {
    ctx.reset();
    ctx.process(root, context);
  }

  @override
  TreeProcessor inverted() {
    return TreeProcessorImpl(root);
  }
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

class InvertedProcessingContext {
  bool _terminated = false;

  void reset() {
    _terminated = false;
  }

  void process(ProcessingNode rootNode, dynamic extContext) {
    rootNode.mark = false;
    late Action nextAction;
    do {
      for (var child in rootNode.children) {
        if (_terminated) {
          return;
        }
        child.mark = false;
        process(child, extContext);
      }
      if (_terminated) {
        return;
      }
      nextAction = rootNode.delegate(extContext, rootNode.data);
    } while (nextAction == Action.repeat);

    if (nextAction == Action.terminate) {
      _terminated = true;
    }

    assert(nextAction != Action.markAndProceed,
        "Marks have no meaning in inverted execution.");
    assert(nextAction != Action.backToMark,
        "Can't return to mark in inverted execution.");
    assert(nextAction != Action.terminateBranch,
        "Can't terminate already processed branch in inverted execution.");
  }
}
