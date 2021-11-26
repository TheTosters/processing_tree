import 'package:collection/collection.dart';
import 'package:processing_tree/processing_node.dart';
import 'package:processing_tree/processing_tree.dart';
import 'package:processing_tree/tree_builder.dart';
import 'package:test/test.dart';

void main() {
  test("Build empty tree", () {
    TreeBuilder builder = TreeBuilder();
    expect(() => builder.build(), throwsA((e) => e is TreeBuilderException));
  });

  test("Build struct", () {
    TreeBuilder builder = TreeBuilder();
    ProcessingNode r = builder.addNode(null, (c, d) => Action.proceed, null);
    ProcessingNode n1 = builder.addNode(r, (c, d) => Action.proceed, null);
    ProcessingNode n2 = builder.addNode(r, (c, d) => Action.proceed, null);
    ProcessingNode n3 = builder.addNode(n1, (c, d) => Action.proceed, null);
    //expected structure
    //      r
    //     / \
    //    n1  n2
    //   /
    //  n3
    Function equals = const ListEquality().equals;
    expect(equals(r.children, [n1, n2]), true);
    expect(equals(n1.children, [n3]), true);
    expect(n2.children.length, 0);
  });

  test("Try to add root twice", () {
    TreeBuilder builder = TreeBuilder();
    builder.addNode(null, (c, d) => Action.proceed, null);
    expect(() => builder.addNode(null, (c, d) => Action.proceed, null),
        throwsA((e) => e is TreeBuilderException));
  });
}
