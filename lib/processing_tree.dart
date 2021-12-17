/// Library for creating static trees of execution.
///
/// This library was proposed to create static template of some algorithm which
/// can be build in runtime. For example building UI widget tree using xml
/// data as a description of such process.
/// Execution of whole tree should be considered as a synchronous operation,
/// all input data which will be processed should be already gathered.
library processing_tree;

export 'src/tree_builder.dart'
    show
        TreeBuilder,
        StackedTreeBuilder,
        XmlTreeBuilder,
        BuildCoordinator,
        ParsedItemType,
        KeyValue,
        BuildAction,
        ParsedItem;
export 'src/tree_processor.dart' show TreeProcessor;
export 'src/processing_node.dart' show Action, PNDelegate;
