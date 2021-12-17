import 'package:collection/collection.dart';
import 'package:processing_tree/processing_node.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

class SimpleCoordinator extends BuildCoordinator {
  Map<String, dynamic>? lastXmlMap;

  @override
  ParsedItem requestData(BuildPhaseState state) {
    switch (state.delegateName) {
      case "xml":
        {
          lastXmlMap = <String, dynamic>{};
          return ParsedItem.from(
              state, _copyDelegate, lastXmlMap, ParsedItemType.owner);
        }
      case "const":
        return ParsedItem.from(
            state, _constDelegate, state.data, ParsedItemType.constValue);
      default:
        throw Exception("Upsii");
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
  void step(BuildAction action, ParsedItem item) {
    //notning
  }
}

class ConstValCoordinator extends BuildCoordinator {
  List<String> actions = [];

  @override
  ParsedItem requestData(BuildPhaseState state) {
    if (state.delegateName == "xml") {
      return ParsedItem.from(
          state, _copyDelegate, state.data, ParsedItemType.owner);
    } else {
      return ParsedItem.from(
          state, _constDelegate, state.data, ParsedItemType.constValue);
    }
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
  void step(BuildAction action, ParsedItem item) {
    actions.add("$action|${item.name}");
  }
}

class ExpParentCoordinator extends BuildCoordinator {
  final Map<String, String> childParent;
  final ParsedItemType type;

  ExpParentCoordinator(this.childParent, this.type);

  @override
  ParsedItem requestData(BuildPhaseState state) {
    expect(state.parentNodeName, childParent[state.delegateName]);
    if (state.parentNodeName == "") {
      //root is always owner
      return ParsedItem.from(
          state, (c, d) => Action.proceed, state.data, ParsedItemType.owner);
    } else {
      return ParsedItem.from(state, (c, d) => Action.proceed, state.data, type);
    }
  }

  @override
  void step(BuildAction action, ParsedItem item) {
    //nothing
  }
}

class SimpleCoordinator2 extends BuildCoordinator {
  final Map<String, ParsedItemType> items;
  final Set<String> result = {};

  SimpleCoordinator2(this.items);

  @override
  ParsedItem requestData(BuildPhaseState state) {
    return ParsedItem.from(state, _addValue, state.data, items[state.delegateName]!);
  }

  @override
  void step(BuildAction action, ParsedItem item) {
    //nothing
  }

  Action _addValue(context, data) {
    result.add(data["name"]);
    return Action.proceed;
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
    expect(() => builder.build("<xml/>"), throwsA((e) => true));
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
      "BuildAction.goLevelDown|xml",
      "BuildAction.newItem|constA",
      "BuildAction.goLevelDown|constA",
      "BuildAction.newItem|constB",
      "BuildAction.goLevelDown|constB",
      "BuildAction.newItem|constC",
      "BuildAction.finaliseItem|constC",
      "BuildAction.goLevelUp|constB",
      "BuildAction.finaliseItem|constB",
      "BuildAction.goLevelUp|constA",
      "BuildAction.finaliseItem|constA",
      "BuildAction.goLevelUp|xml",
      "BuildAction.finaliseItem|xml"
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
      "BuildAction.goLevelDown|xml",
      "BuildAction.newItem|constA",
      "BuildAction.goLevelDown|constA",
      "BuildAction.newItem|constB",
      "BuildAction.finaliseItem|constB",
      "BuildAction.newItem|constC",
      "BuildAction.finaliseItem|constC",
      "BuildAction.goLevelUp|constA",
      "BuildAction.finaliseItem|constA",
      "BuildAction.goLevelUp|xml",
      "BuildAction.finaliseItem|xml"
    ];
    Function equals = const ListEquality().equals;
    expect(equals(c.actions, expAct), true);
  });

  test("Coordinated - no levelDown/Up for leaf only root", () {
    final c = ConstValCoordinator();
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(c);
    var prc = builder.build('''
      <xml>
      </xml>
    ''');
    Map<String, dynamic> result = {};
    prc.process(result);
    final expAct = ["BuildAction.newItem|xml", "BuildAction.finaliseItem|xml"];
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

  test("Coordinated - Don't add null const val", () {
    final coord = SimpleCoordinator();
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coord);
    final xml = '''
      <xml>
        <const/>
      </xml>
    ''';
    builder.build(xml);
    expect(coord.lastXmlMap?.isEmpty, true);
  });

  test("Coordinated - verify parents", () {
    final xml = '''
      <A>
        <B>
          <D/>
        </B>
        <C>
          <E>
            <G/>
          </E>
          <F></F>
          <H>
            <I/>
          </H>
        </C>
      </A>
    ''';
    final childParent = {
      "A": "",
      "B": "A",
      "C": "A",
      "D": "B",
      "E": "C",
      "F": "C",
      "H": "C",
      "G": "E",
      "I": "H",
    };
    //for node types Owner
    var coord = ExpParentCoordinator(childParent, ParsedItemType.owner);
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(coord);
    builder.build(xml);

    //for node types ConstVal
    coord = ExpParentCoordinator(childParent, ParsedItemType.constValue);
    builder = XmlTreeBuilder.coordinated(coord);
    builder.build(xml);
  });

  test("Coordinated - ConstVal delegates should not be called at process", () {
    final c = SimpleCoordinator2({
      "owner": ParsedItemType.owner,
      "owner2": ParsedItemType.owner,
      "owner3": ParsedItemType.owner,
      "const": ParsedItemType.constValue,
      "const2": ParsedItemType.constValue,
      "const3": ParsedItemType.constValue,
    });
    XmlTreeBuilder builder = XmlTreeBuilder.coordinated(c);
    var prc = builder.build('''
      <owner name="owner">
        <owner2 name="owner2">
          <const name="const"/>
        </owner2>
        <owner3 name="owner3">
          <const2 name="const2">
            <const3 name="const3"/>
          </const2>
        </owner3>
      </owner>
    ''');

    // const value delegates are executed at build phase
    final expConstValues = {"const", "const2", "const3"};
    Function equals = const SetEquality().equals;
    expect(equals(c.result, expConstValues), true);

    // owner delegates are executed at process phase
    c.result.clear();
    prc.process(null);
    final expOwners = {"owner", "owner2", "owner3"};
    expect(equals(c.result, expOwners), true);
  });
}
