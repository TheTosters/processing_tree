import 'tree_processor.dart';
import 'processing_node.dart';

class TreeBuilderException implements Exception {
  final String message;

  TreeBuilderException(this.message);
}

/// Generic processing tree builder.
///
/// Allows creating tree by direct adding nodes to it's parents, and finally
/// results [TreeProcessor]. This is very generic class consider usage of
/// [StackedTreeBuilder] instead.
class TreeBuilder {
  ProcessingNode? _root;

  /// Adds [delegate] along with it's [data] to processing tree structure
  ///
  /// If [parent] is null then root node is add, this can be done only once or
  /// [TreeBuilderException] will be thrown. Each next call to this method
  /// should provide [parent] object for newly added node. As a parent to
  /// subnode object returned from previous call should be used:
  ///
  /// ```dart
  ///   var root = builder.add(null, (c,d) => {return Action.proceed}, null);
  ///   var s1 = builder.add(root, (c,d) => {return Action.proceed}, null);
  ///   var s2 = builder.add(root, (c,d) => {return Action.proceed}, null);
  ///   var s3 = builder.add(s1, (c,d) => {return Action.proceed}, null);
  /// ```
  ///
  /// after execution of this code following tree is created:
  /// ```
  ///          root
  ///          /  \
  ///         s1  s2
  ///        /
  ///       s3
  /// ```
  dynamic addNode(dynamic parent, PNDelegate delegate, dynamic data) {
    if (parent == null) {
      if (_root == null) {
        _root = ProcessingNode(delegate, [], data);
        return _root;
      }
      throw TreeBuilderException("Tree builder already have root!");
    }
    assert(parent is ProcessingNode);
    ProcessingNode nParent = parent as ProcessingNode;
    var node = ProcessingNode(delegate, [], data);
    nParent.children.add(node);
    return node;
  }

  /// Returns object which might be used to execute processing tree.
  ///
  /// If no nodes are add, then [TreeBuilderException] is thrown, otherwise
  /// ready to use implementation of [TreeProcessor] is returned.
  TreeProcessor build() {
    if (_root == null) {
      throw TreeBuilderException("No root node");
    }
    return TreeProcessorImpl(_root!);
  }
}

/// Builds processing tree in stack like manner
///
/// In contrast to [TreeBuilder] this builder doesn't require to store parent
/// reference in user code while creating sub nodes.
class StackedTreeBuilder {
  final ProcessingNode _root;
  final Map<ProcessingNode, ProcessingNode> _parenthood = {};
  late ProcessingNode _current;

  StackedTreeBuilder(PNDelegate delegate, dynamic data)
      : this._(ProcessingNode(delegate, [], data));

  StackedTreeBuilder._(ProcessingNode root)
      : _root = root,
        _current = root;

  /// Adds node and make it as a parent for next operations.
  ///
  /// Consider tree:
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  /// ```
  /// if S2 is current node, then call to this method will result in adding node
  /// S4 as shown below, from this moment S4 is parent for next operation
  /// (in contrast to [addChild])
  ///
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  ///     /
  ///    S4
  /// ```
  /// so calling it again will result in adding S5.
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  ///     /
  ///    S4
  ///   /
  ///  S5
  /// ```
  void push(PNDelegate delegate, dynamic data) {
    var node = ProcessingNode(delegate, [], data);
    _current.children.add(node);
    _parenthood[node] = _current;
    _current = node;
  }

  /// Set parent of current node, as a parent for next operations.
  ///
  /// Think about it as: move one up level in stack. If current node is root and
  /// this method is called [TreeBuilderException] is thrown
  void levelUp() {
    if (_current == _root) {
      throw TreeBuilderException("Already at top of tree");
    }
    _current = _parenthood[_current]!;
  }

  /// Add a node which has no children, don't change current parent node.
  ///
  /// This method should be used to add leaf to parent. If for some reason
  /// you need to go back to node added by this method use [nextSibling] and
  /// [prevSibling] to navigate back. By default node added by this method
  /// can't have children, trying add child will result in exception being
  /// thrown. If for some reason this behaviour is not acceptable pass [leaf]
  /// argument as false.
  ///
  /// Consider tree:
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  /// ```
  /// if S2 is current node, then call to this method will result in adding node
  /// S4 as shown below, but current node still is S2 (in contrast to [push])
  ///
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  ///     /
  ///    S4
  /// ```
  /// so calling it again will result in adding S5. For both S4 and S5 no
  /// children should be added, if [leaf] argument was false.
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  ///     /  \
  ///    S4  S5
  /// ```
  void addChild(PNDelegate delegate, dynamic data, {bool leaf = true}) {
    var node = ProcessingNode(delegate, leaf ? const [] : [], data);
    _current.children.add(node);
    _parenthood[node] = _current;
  }

  /// Select next child node in parent of current node.
  ///
  /// Consider tree:
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  /// ```
  /// if current node is S2, after call to this method S3 will be current node.
  /// If next sibling is selected, method returns true.
  /// If there is no next sibling this method do nothing, and returns false.
  bool nextSibling() {
    if (_current == _root) {
      return false;
    }
    ProcessingNode parent = _parenthood[_current]!;
    int index = parent.children.indexOf(_current);
    index++;
    if (index == parent.children.length) {
      return false;
    }
    _current = parent.children[index];
    return true;
  }

  /// Select prev child node in parent of current node.
  ///
  /// Consider tree:
  /// ```
  ///        S1
  ///       /  \
  ///      S2  S3
  /// ```
  /// if current node is S3, after call to this method S2 will be current node.
  /// If prev sibling is selected, method returns true.
  /// If there is no prev sibling this method do nothing, and returns false.
  bool prevSibling() {
    if (_current == _root) {
      return false;
    }
    ProcessingNode parent = _parenthood[_current]!;
    int index = parent.children.indexOf(_current);
    index--;
    if (index < 0) {
      return false;
    }
    _current = parent.children[index];
    return true;
  }

  /// Finalize build and returns [TreeProcessor] for newly formed tree.
  TreeProcessor build() {
    return TreeProcessorImpl(_root);
  }
}
