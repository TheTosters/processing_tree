import 'dart:convert';

import 'package:processing_tree/processing_tree.dart';
import 'package:xml/xml.dart';

void main() {
  var xml = '''
  <Persons>
    <Person name="Jack" gender="male"/>
    <Person name="Hanna" gender="female"/>
  </Persons>
  ''';
  final xmlDoc = XmlDocument.parse(xml);

  Map<String, dynamic> objects = {"xmlDoc": xmlDoc, "map": <String, dynamic>{}};
  TreeProcessor processor = _buildTransformTree();
  processor.process(objects);
  print(objects["result"]);
}

Action _expectPersons(context, data) {
  final XmlDocument xmlDoc = context["xmlDoc"];
  if (xmlDoc.rootElement.name != XmlName("Persons")) {
    return Action.terminate;
  }

  //container for temporary state values
  final map = context["map"];
  List<dynamic> children = [];
  map[data] = children;

  //Select first xml node to be processed
  context["curXmlNode"] = xmlDoc.rootElement.firstElementChild;
  context["children"] = children;

  return Action.proceed;
}

Action _expectPerson(context, data) {
  XmlElement xmlElement = context["curXmlNode"];
  if (xmlElement.name != XmlName("Person")) {
    return Action.terminate;
  }

  Map<String, dynamic> childFields = {
    "name": xmlElement.getAttribute("name"),
    "gender": xmlElement.getAttribute("gender"),
  };

  final List<dynamic> children = context["children"];
  children.add({data: childFields});

  if (xmlElement.nextElementSibling != null) {
    context["curXmlNode"] = xmlElement.nextElementSibling;
    return Action.repeat;
  }
  return Action.proceed;
}

Action _encodeJson(context, data) {
  final map = context["map"];
  JsonEncoder encoder = JsonEncoder.withIndent('  ');
  context["result"] = encoder.convert(map);
  return Action.proceed;
}

TreeProcessor _buildTransformTree() {
  StackedTreeBuilder builder = StackedTreeBuilder(_expectPersons, "JPersons");
  builder.push(_expectPerson, "JP");
  builder.push(_encodeJson, "JP");
  return builder.build();
}
