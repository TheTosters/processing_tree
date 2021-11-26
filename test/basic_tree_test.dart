import 'package:processing_tree/processing_tree.dart';
import 'package:test/test.dart';
import 'package:collection/collection.dart';

Action addToCtx(context, data) {
  context.addAll(data);
  return Action.proceed;
}

Action addToCtxAndTerminate(context, data) {
  context.addAll(data);
  return Action.terminate;
}

Action addToCtxAndTerminateBranch(context, data) {
  context.addAll(data);
  return Action.terminateBranch;
}

Action repeatOnce(context, data) {
  if (context.contains(data)) {
    context.add(data);
    return Action.proceed;
  } else {
    context.add(data);
    return Action.repeat;
  }
}

Action markFirstPass(context, data) {
  if (context.contains(data)) {
    context.add(data);
    return Action.proceed;
  } else {
    context.add(data);
    return Action.markAndProceed;
  }
}

Action returnToMarkAtFirstPass(context, data) {
  if (context.contains(data)) {
    context.add(data);
    return Action.proceed;
  } else {
    context.add(data);
    return Action.backToMark;
  }
}

void main() {
  test("check single branch", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, {"1"});
    var n2 = builder.addNode(n1, addToCtx, {"2"});
    builder.addNode(n2, addToCtx, {"3"});

    Set<String> result = {};
    builder.build().process(result);
    expect(result.containsAll({"1", "2", "3"}), true);
  });

  test("check single branch - terminate", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, {"1"});
    var n2 = builder.addNode(n1, addToCtxAndTerminate, {"2"});
    builder.addNode(n2, addToCtx, {"3"});

    Set<String> result = {};
    builder.build().process(result);
    expect(result.containsAll({"1", "2"}), true);
  });

  test("check single branch - terminateBranch", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, {"1"});
    var n2 = builder.addNode(n1, addToCtxAndTerminateBranch, {"2"});
    builder.addNode(n2, addToCtx, {"3"});

    Set<String> result = {};
    builder.build().process(result);
    expect(result.containsAll({"1", "2"}), true);
  });

  test("check two branches", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, addToCtx, ["2"]);
    builder.addNode(n2, addToCtx, ["2-1"]);

    n2 = builder.addNode(n1, addToCtx, ["3"]);
    builder.addNode(n2, addToCtx, ["3-1"]);

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(equals(result, ["1", "2", "2-1", "3", "3-1"]), true);
  });

  test("check two branches - terminate", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, addToCtxAndTerminate, ["2"]);
    builder.addNode(n2, addToCtx, ["2-1"]);

    n2 = builder.addNode(n1, addToCtx, ["3"]);
    builder.addNode(n2, addToCtx, ["3-1"]);

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(equals(result, ["1", "2"]), true);
  });

  test("check two branches - terminate branch", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, addToCtxAndTerminateBranch, ["2"]);
    builder.addNode(n2, addToCtx, ["2-1"]);

    n2 = builder.addNode(n1, addToCtx, ["3"]);
    builder.addNode(n2, addToCtx, ["3-1"]);

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(equals(result, ["1", "2", "3", "3-1"]), true);
  });

  test("check simple repeat", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, repeatOnce, "2");
    builder.addNode(n2, addToCtx, ["3"]);

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(equals(result, ["1", "2", "2", "3"]), true);
  });

  test("check simple mark - back", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, markFirstPass, "2");
    builder.addNode(n2, returnToMarkAtFirstPass, "3");

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(equals(result, ["1", "2", "3", "2", "3"]), true);
  });

  test("check nested mark - back", () {
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    var n2 = builder.addNode(n1, markFirstPass, "2");
    var n3 = builder.addNode(n2, markFirstPass, "3");
    var n4 = builder.addNode(n3, returnToMarkAtFirstPass, "4");
    builder.addNode(n4, returnToMarkAtFirstPass, "5");

    List<String> result = [];
    builder.build().process(result);
    Function equals = const ListEquality().equals;
    expect(
        equals(result, ["1", "2", "3", "4", "3", "4", "5", "2", "3", "4", "5"]),
        true);
  });

  test("check two branch mark", () {
    //mark and back between branches is prohibited
    TreeBuilder builder = TreeBuilder();
    var n1 = builder.addNode(null, addToCtx, ["1"]);
    builder.addNode(n1, markFirstPass, "2");
    builder.addNode(n1, returnToMarkAtFirstPass, "3");

    List<String> result = [];
    expect(() => builder.build().process(result), throwsRangeError);
  });
}
