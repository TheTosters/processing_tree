library processing_tree;

import 'package:processing_tree/processing_node.dart';

/// Interface which allows execution of processing tree.
abstract class TreeProcessor {
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
class TreeProcessorImpl implements TreeProcessor {
  final ProcessingNode root;
  final ProcessingContext ctx = ProcessingContext();

  TreeProcessorImpl(this.root);

  @override
  void process(dynamic context) {
    ctx.reset();
    ctx.process(root, context);
  }
}
