import 'package:xml/xml.dart';

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
  /// subNode object returned from previous call should be used:
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

/// Helper interface for automated builders. Allows conversion between
/// serialized form of processing tree into structures used in ready to use tree.
abstract class DelegateProvider {
  /// Returns delegate which is assigned for name.
  PNDelegate? delegate(String name);

  /// Converts arguments associated with delegate, into form which should be
  /// passed as [data] argument for [PNDelegate]
  dynamic delegateData(String delegateName, Map<String, dynamic> rawData);
}

/// Tells builder if given node should be considered as a value or algorithm
/// element
enum ParsedItemType {
  /// This is node which represents constant value. While parsing call to
  /// delegate will be performed, returned value will be passed to parent node
  /// [data] collection. Item marked with this type will not create node in
  /// processing tree, it must be a leaf!
  ///
  /// *Contract #1:* delegate of constValue takes KeyValue object as a context
  /// and can change name/value fields as needed.
  ///
  /// *Contract #2:* Parent data is not null and it conforms to
  /// operator [](String name)=dynamic. To store result of delegate call.
  ///
  /// *Contract #3:* Result value of delegate different then [Action.proceed] is
  /// considered as error and TreBuildException is thrown.
  constValue,

  /// This is node which is part of algorithm, it should be represented as
  /// a delegate and data in Processing Tree
  owner }

class _WrappedDelegateProvider extends BuildCoordinator {
  final DelegateProvider _provider;

  _WrappedDelegateProvider(this._provider);

  @override
  ParsedItemType itemType(String name) => ParsedItemType.owner;

  @override
  PNDelegate? delegate(String name) => _provider.delegate(name);

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) =>
      _provider.delegateData(delegateName, rawData);
}

/// Interface which further extends [DelegateProvider] to return information
/// about folding tree nodes.
///
/// If for some reasons tree contains nodes which while processing are
/// identified as values (const or changeable) which will not perform any
/// actions those items will not be built into tree as a processing node, rather
/// calculated and added to parent [data] collection as computed.
abstract class BuildCoordinator extends DelegateProvider {
  ParsedItemType itemType(String name);

  static fromProvider(DelegateProvider provider) =>
      _WrappedDelegateProvider(provider);
}

class _ParsedItem {
  final String name;
  final PNDelegate delegate;
  final dynamic data;
  final bool isLeaf;
  final ParsedItemType type;

  _ParsedItem(this.name, this.delegate, this.data, this.isLeaf, this.type);
}

class XmlTreeBuilder {
  TreeProcessor? _processor;
  final BuildCoordinator provider;

  XmlTreeBuilder(DelegateProvider provider)
      : provider = BuildCoordinator.fromProvider(provider);

  XmlTreeBuilder.coordinated(this.provider);

  /// Returns object which might be used to execute processing tree.
  /// If xml fail to parse, then [XmlParserException] is thrown. If xml is
  /// valid but it's unable to build tree then [TreeBuilderException] is thrown,
  /// otherwise ready to use implementation of [TreeProcessor] is returned.
  TreeProcessor build(String xmlStr) {
    _parseXml(xmlStr);
    if (_processor == null) {
      throw TreeBuilderException("Unable to build tree.");
    }
    return _processor!;
  }

  void _parseXml(String xmlStr) {
    final xmlDoc = XmlDocument.parse(xmlStr);
    XmlElement xmlElement = xmlDoc.rootElement;
    final _ParsedItem item = _processElement(xmlElement);
    StackedTreeBuilder builder = StackedTreeBuilder(item.delegate, item.data);
    _processSubLevel(xmlElement, builder, false);
    _processor = builder.build();
  }

  Map<String, dynamic> _extractArguments(XmlElement xmlElement) {
    final Map<String, dynamic> inData = <String, dynamic>{};
    for (var attr in xmlElement.attributes) {
      inData[attr.name.toString()] = attr.value;
    }
    return inData;
  }

  _ParsedItem _processElement(XmlElement xmlElement) {
    final nodeName = xmlElement.name.toString();
    final delegate = provider.delegate(nodeName);
    final data = provider.delegateData(nodeName, _extractArguments(xmlElement));
    if (delegate == null) {
      throw TreeBuilderException("No delegate for xml node name '$nodeName'");
    }
    final isLeaf = xmlElement.firstElementChild == null;
    final type = provider.itemType(nodeName);
    if (type == ParsedItemType.constValue && !isLeaf){
      throw TreeBuilderException("$nodeName: constValue must be a leaf!");
    }
    return _ParsedItem(nodeName, delegate, data, isLeaf, type);
  }

  void _processSubLevel(
      XmlElement xmlElement, StackedTreeBuilder builder, bool popLevelAtEnd) {
    for (var subElement in xmlElement.childElements) {
      final _ParsedItem item = _processElement(subElement);

      //See documentation of ParsedItemType for details
      if (item.type == ParsedItemType.constValue) {
        _handleAsConstValue(builder, item);
        continue;

      } else {
        if (item.isLeaf) {
          builder.addChild(item.delegate, item.data);
        } else {
          builder.push(item.delegate, item.data);
          _processSubLevel(subElement, builder, true);
          if (popLevelAtEnd) {
            builder.levelUp();
          }
        }
      }
    }
  }

  void _handleAsConstValue(StackedTreeBuilder builder, _ParsedItem item) {
    KeyValue result = KeyValue(item.name, null);
    if (item.delegate(result, item.data) != Action.proceed) {
      throw TreeBuilderException(
          "Delegate for ${item.name} didn't return Action.proceed");
    }
    builder._current.data[result.key] = result.value;
  }
}

class KeyValue {
  String key;
  dynamic value;

  KeyValue(this.key, this.value);
}
