import 'package:collection/collection.dart';
import 'package:processing_tree/processing_node.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

class NoDelegateProvider extends DelegateProvider {
  @override
  PNDelegate? delegate(String name) => null;

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) => null;
}

class MarkedDelegateProvider extends DelegateProvider {
  Set<String> names = {};

  @override
  PNDelegate? delegate(String name) {
    names.add(name);
    return (c, d) => Action.proceed;
  }

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) {
    for(var entry in rawData.entries) {
      names.add(entry.key + ":" + entry.value);
    }
    return null;
  }
}

void main() {
  test("No delegate", () {
    //it's illegal to have no delegate returned by provider
    XmlTreeBuilder builder = XmlTreeBuilder(NoDelegateProvider());
    expect(() => builder.build("<xml/>"), throwsA((e) => e is TreeBuilderException));
  });

  test("Check calls to provider", () {
    //it's illegal to have no delegate returned by provider
    var prv = MarkedDelegateProvider();
    XmlTreeBuilder builder = XmlTreeBuilder(prv);
    builder.build('''
      <xml>
        <NodeA _trr1="attr">
          <NodeB _x="xx"/>
        </NodeA>
      </xml>
    ''');
    Function equals = const SetEquality().equals;
    Set<String> expected = {"xml", "NodeA", "NodeB", "_trr1:attr", "_x:xx"};
    expect(equals(prv.names, expected), true);
  });

  test("Malformed xml", () {
    XmlTreeBuilder builder = XmlTreeBuilder(NoDelegateProvider());
    expect(() => builder.build("<xml/"), throwsA((e) => e is XmlParserException));
  });
}