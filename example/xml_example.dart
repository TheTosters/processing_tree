import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/src/tree_builder.dart';

class CalculatorCtx {
  double inValue = 0;
  double result = 0;
  List<double> stack = [];
}

class Provider implements DelegateProvider {
  final Map<String, dynamic> objects;

  Provider(this.objects);

  @override
  PNDelegate? delegate(String name) {
    switch (name.toLowerCase()) {
      case "calculator":
        return _calc;
      case "add":
        return _add;
      case "sub":
        return _sub;
      case "stack":
        return _stack;
      case "popandmultiply":
        return _popAndMultiply;
      default:
        return null;
    }
  }

  Action _calc(dynamic context, dynamic data) {
    final CalculatorCtx calcContext = context;
    calcContext.result = calcContext.inValue;
    return Action.proceed;
  }

  Action _add(dynamic context, dynamic data) {
    final CalculatorCtx calcContext = context;
    final double operand = data;
    calcContext.result = calcContext.result + operand;
    return Action.proceed;
  }

  Action _sub(dynamic context, dynamic data) {
    final CalculatorCtx calcContext = context;
    final double operand = data;
    calcContext.result = calcContext.result - operand;
    return Action.proceed;
  }

  Action _stack(dynamic context, dynamic data) {
    final CalculatorCtx calcContext = context;
    calcContext.stack.add(calcContext.result);
    calcContext.result = 0;
    return Action.proceed;
  }

  Action _popAndMultiply(dynamic context, dynamic data) {
    final CalculatorCtx calcContext = context;
    double value = calcContext.stack.removeLast();
    calcContext.result *= value;
    return Action.proceed;
  }

  @override
  delegateData(String delegateName, Map<String, dynamic> rawData) {
    if (rawData.isNotEmpty) {
      String value = rawData["value"] as String;
      if (value.startsWith("\$")) {
        return objects[value.substring(1)];
      } else if (value == "@") {
        return objects["inCtx"].inValue;
      }
      return double.parse(value);
    } else {
      return null;
    }
  }
}

void main() {
  var xml = '''
  <!-- opertation is f(x) = (x + val - 5) * (4 + val + x) --> 
  <Calculator>
    <Add value="\$val"/>
    <Sub value="5"/>
    <Stack>
      <Add value="4"/>
      <Add value="\$val"/>
      <Add value="@"/>
      <PopAndMultiply/>
    </Stack>
  </Calculator>
  ''';
  double val = 7;
  CalculatorCtx inCtx = CalculatorCtx()..inValue = 11;
  XmlTreeBuilder builder =
      XmlTreeBuilder(Provider({"val": val, "inCtx": inCtx}));
  var processor = builder.build(xml);
  processor.process(inCtx);
  print("F(${inCtx.inValue}) = (${inCtx.inValue} + $val - 5) * "
      "(4 + $val + ${inCtx.inValue}) => ${inCtx.result}");
}
