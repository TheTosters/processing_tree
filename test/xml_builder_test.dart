import 'package:collection/collection.dart';
import 'package:processing_tree/processing_node.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

class SimpleCoordinator extends BuildCoordinator {
  @override
  PNDelegate? delegate(String name) {
    switch (name) {
      case "xml":
        return _copyDelegate;
      case "const":
        return _constDelegate;
      default:
        return null;
    }
  }

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) {
    switch (delegateName) {
      case "xml":
        return <String, dynamic>{};
      case "const":
        return rawData;
      default:
        return ParsedItemType.owner;
    }
  }

  @override
  ParsedItemType itemType(String name) {
    switch (name) {
      case "xml":
        return ParsedItemType.owner;
      case "const":
        return ParsedItemType.constValue;
      default:
        return ParsedItemType.owner;
    }
  }

  Action _copyDelegate(context, data) {
    context.addAll(data);
    return Action.proceed;
  }

  Action _constDelegate(context, data) {
    context.value = data["value"];
    return Action.proceed;
  }

  @override
  void step(BuildAction action, String nodeName) {
    // TODO: implement step
  }
}

class ConstValCoordinator extends BuildCoordinator {
  List<String> actions = [];

  @override
  PNDelegate? delegate(String name) {
    return name == "xml" ? _copyDelegate : _constDelegate;
  }

  Action _copyDelegate(context, data) {
    context.addAll(data);
    return Action.proceed;
  }

  Action _constDelegate(context, data) {
    if (context.value != null && context.value is Map) {
      context.value = context.value.entries.join(",") + data["value"];
    } else {
      context.value = data["value"];
    }
    return Action.proceed;
  }

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) => rawData;

  @override
  ParsedItemType itemType(String name) =>
      name == "xml" ? ParsedItemType.owner : ParsedItemType.constValue;

  @override
  void step(BuildAction action, String nodeName) {
    actions.add("$action|$nodeName");
  }
}

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
    for (var entry in rawData.entries) {
      names.add(entry.key + ":" + entry.value);
    }
    return null;
  }
}

void main() {
  test("No delegate", () {
    //it's illegal to have no delegate returned by provider
    XmlTreeBuilder builder = XmlTreeBuilder(NoDelegateProvider());
    expect(() => builder.build("<xml/>"),
        throwsA((e) => e is TreeBuilderException));
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
    expect(
        () => builder.build("<xml/"), throwsA((e) => e is XmlParserException));
  });

  test("Coordinated - constValue not a leaf", () {
    //ConstValue node must be a leaf
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(SimpleCoordinator());
    var xml = '''
      <xml>
        <const _trr1="attr">
          <UnAllowed/>
        </const>
      </xml>
    ''';
    expect(() => builder.build(xml), throwsA((e) => e is TreeBuilderException));
  });

  test("Coordinated - consume constants", () {
    //values should not create nodes in processing tree
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(SimpleCoordinator());
    var prc = builder.build('''
      <xml>
        <const value="const_val"/>
      </xml>
    ''');
    Map<String, dynamic> result = {};
    prc.process(result);
    expect(result["const"], "const_val");
  });

  test("Coordinated - consume stacked constants", () {
    final c = ConstValCoordinator();
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(c);
    var prc = builder.build('''
      <xml>
        <constA value="const_val_lvl1">
          <constB value="const_val_lvl2">
            <constC value="const_val_lvl3"/>
          </constB>
        </constA>
      </xml>
    ''');
    Map<String, dynamic> result = {};
    prc.process(result);
    expect(result["constA"],
        "MapEntry(constB: MapEntry(constC: const_val_lvl3)const_val_lvl2)const_val_lvl1");
    final expAct = [
      "BuildAction.newItem|xml",
      "BuildAction.newItem|constA",
      "BuildAction.goLevelDown|constA",
      "BuildAction.newItem|constB",
      "BuildAction.goLevelDown|constB",
      "BuildAction.newItem|constC",
      "BuildAction.finaliseConstVal|constC",
      "BuildAction.goLevelUp|constB",
      "BuildAction.finaliseConstVal|constB",
      "BuildAction.goLevelUp|constA",
      "BuildAction.finaliseConstVal|constA"
    ];
    Function equals = const ListEquality().equals;
    expect(equals(c.actions, expAct), true);
  });

  test("Coordinated - consume siblings constants", () {
    final c = ConstValCoordinator();
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(c);
    var prc = builder.build('''
      <xml>
        <constA value="const_val_lvl1">
          <constB value="const_val_lvl2"/>
          <constC value="const_val_lvl3"/>
        </constA>
      </xml>
    ''');
    Map<String, dynamic> result = {};
    prc.process(result);
    expect(result["constA"],
        "MapEntry(constB: const_val_lvl2),MapEntry(constC: const_val_lvl3)const_val_lvl1");
    final expAct = [
      "BuildAction.newItem|xml",
      "BuildAction.newItem|constA",
      "BuildAction.goLevelDown|constA",
      "BuildAction.newItem|constB",
      "BuildAction.finaliseConstVal|constB",
      "BuildAction.newItem|constC",
      "BuildAction.finaliseConstVal|constC",
      "BuildAction.goLevelUp|constA",
      "BuildAction.finaliseConstVal|constA"
    ];
    Function equals = const ListEquality().equals;
    expect(equals(c.actions, expAct), true);
  });

  test("Coordinated - Illegal owner / constVal mix", () {
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(ConstValCoordinator());
    final xml = '''
      <xml>
        <constA value="const_val_lvl1">
          <xml/>
        </constA>
      </xml>
    ''';
    expect(() => builder.build(xml), throwsA((e) => e is TreeBuilderException));
  });
}
