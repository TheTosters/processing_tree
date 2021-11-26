import 'package:collection/collection.dart';
import 'package:processing_tree/processing_node.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:test/test.dart';

Action addToCtx(context, data) {
  context.add(data);
  return Action.proceed;
}

void main() {
  test("Build empty tree", () {
    StackedTreeBuilder builder =
        StackedTreeBuilder((c, d) => Action.proceed, null);
    builder.build();
  });

  test("Check simple push", () {
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    builder.addChild(addToCtx, "n1");
    builder.addChild(addToCtx, "n2");

    //Since we use Add parent should not change, r will not have any sibling
    expect(builder.nextSibling(), false);

    //If we are root, we cant go up
    expect(() => builder.levelUp(), throwsA((e) => e is TreeBuilderException));

    var processor = builder.build();
    List<String> tmp = [];
    processor.process(tmp);

    //expected structure r - n1 - n2
    Function equals = const ListEquality().equals;
    expect(equals(tmp, ["r", "n1", "n2"]), true);
  });

  test("Check simple add", () {
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    builder.push(addToCtx, "n1");
    builder.push(addToCtx, "n2");
    var processor = builder.build();
    List<String> tmp = [];
    processor.process(tmp);

    //expected structure r - n1 - n2
    Function equals = const ListEquality().equals;
    expect(equals(tmp, ["r", "n1", "n2"]), true);
  });

  test("Build simple tree", () {
    //expected structure
    //      r
    //     / \
    //    n1  n2
    //   /
    //  n3
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    builder.push(addToCtx, "n1");
    builder.addChild(addToCtx, "n3");
    builder.levelUp();
    builder.addChild(addToCtx, "n2");

    var processor = builder.build();
    List<String> tmp = [];
    processor.process(tmp);

    //expected structure r - n1 - n2
    Function equals = const ListEquality().equals;
    expect(equals(tmp, ["r", "n1", "n3", "n2"]), true);
  });

  test("Check navigate up", () {
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    for (int t = 1; t < 5; t++) {
      builder.push(addToCtx, "n");
    }
    for (int t = 1; t < 5; t++) {
      builder.levelUp();
    }
    expect(() => builder.levelUp(), throwsA((e) => e is TreeBuilderException));
  });

  test("Check siblings", () {
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    for (int t = 1; t < 5; t++) {
      builder.addChild(addToCtx, "n");
    }
    builder.push(addToCtx, "n");

    for (int t = 1; t < 5; t++) {
      expect(builder.prevSibling(), true);
    }
    expect(builder.prevSibling(), false);

    for (int t = 1; t < 5; t++) {
      expect(builder.nextSibling(), true);
    }
    expect(builder.nextSibling(), false);
  });

  test("Check leaf", () {
    //Adding child to leaf should fail with exception
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    builder.addChild(addToCtx, "l");
    builder.push(addToCtx, "n");
    expect(builder.prevSibling(), true);
    expect(() => builder.push(addToCtx, "error"), throwsA((e) => true));
  });

  test("Check leaf - allow children", () {
    //Adding child to leaf should fail with exception
    StackedTreeBuilder builder = StackedTreeBuilder(addToCtx, "r");
    builder.addChild(addToCtx, "l", leaf: false);
    builder.push(addToCtx, "n");
    expect(builder.prevSibling(), true);
    builder.push(addToCtx, "ok");
  });
}
