# Processing tree
[![Pub Package](https://img.shields.io/pub/v/processing_tree.svg)](https://pub.dev/packages/processing_tree)
[![GitHub Issues](https://img.shields.io/github/issues/TheTosters/processing_tree.svg)](https://github.com/TheTosters/processing_tree/issues)
[![GitHub Forks](https://img.shields.io/github/forks/TheTosters/processing_tree.svg)](https://github.com/TheTosters/processing_tree/network)
[![GitHub Stars](https://img.shields.io/github/stars/TheTosters/processing_tree.svg)](https://github.com/TheTosters/processing_tree/stargazers)
[![GitHub License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/TheTosters/processing_tree/blob/master/LICENSE)

Dart library for building and executing static trees of execution created in runtime.

# When to use it
The main idea behind usage of this library is when there is a need to build builder in runtime. So for
example there is a bunch of input files which will build some objects, but parse operation is complex
and heavy. So intention is to do read and parse only once, and then use created builder any time needed.

# Getting started
Installation
Follow the installation instructions on [dart packages](https://pub.dev/packages/xml/install).

Import the library into your Dart code using:

```
import 'package:processing_tree/processing_tree.dart';
```

Use one of provided builders to prepare structure of tree (please refer to example) and binding with
your code which will be executed while using tree. Finally call ```build``` function on builder to
obtain instance of ```TreeProcessor```. From this moment tree is ready to processing data call
```process``` function on obtained ```TreeProcessor``` instance to perform execution.

# Building
Currently only possibility to build tree is to use one of provided builders, or write your own one
using existing builders as base for it.

## TreeBuilder
The most easy and flexible builder is a ```TreeBuilder```, it allows direct adding nodes to it's parents.
The first call od ```addNode``` with parent equals ```null``` is used to define root. Every next call to
```addNode``` requires passing parent node for newly added. In this way whole structure of tree can be
done through builder API. In the end single call to ```build``` returns instance of ```TreeProcessor```
which can be used to execute tree.

## TreeBuilder
More advanced version of ```TreeBuilder``` is a ```StackedTreeBuilder``` it allows to work with building
process in more organized way. This reduce need to store intermediate parent references to build tree.
In the beginning you need to pass data needed to create root of tree into ```StackedTreeBuilder```
constructor. After this moment you can add or navigate on constructed tree structure. By calling
method ```push``` new node is attached to tree, and became parent for further operations. If added node
should not be parent for next operations call ```addChild```, this creates new leaf in destination tree.
To navigate through children in current level please call to ```prevSibling``` and ```nextSibling```.
When all children on given level are add call to ```levelUp``` will select parent of current parent as
a node for next operation. In the end single call to ```build``` returns instance of ```TreeProcessor```
which can be used to execute tree.

## XmlTreeBuilder
This is the most advanced builder which mix xml deserialization and tree building. It allows to parse
any custom XML into processing tree. To achieve this there is need of data provider which can interpret
meaning of nodes and select proper delegates and data for it. To achieve this two approaches are
implemented. For simple trees use ```DelegateProvider``` for greater level of control use
```BuildCoordinator```.

### Using ```XmlTreeBuilder``` with ```DelegateProvider```
Parsing of data using ```DelegateProvider``` implementation if designed for xml's for which selecting
delegate can be easy determined by xml element name. Override method ```delegate``` which returns
delegate to be used for found xml element. Second method which need to be overridden is ```delegateData```.
It accepts two arguments a ```delegateName``` same as previous method, and ```Map<String,dynamic>```.
This method allow to process data read from xml element attributes into form which is expected by delegate.
As a result of this method any object can be used, it will be later passed to delegate while executing
processing tree. Whooaaa... maybe some example :)
```xml
  <add>
    <int value="12"/>
    <double value="42"/>
  </add>
```
While parsing this xml 3x call to ```delegate``` will be done, passed delegateName will be ```add```,
```int``` and ```double```. Responsibility of ```delegate``` delegate method is to return proper delegates
which know what to do with data. But what data?
Again for this xml there will be 3x call to ```delegateData``` with following values:
- delegateName: "add", data: {}
- delegateName: "int", data: {"value": "12"}
- delegateName: "double", data: {"value": "42"}
Now we need to understands what will be resulting processing tree? It will look like:
```
             PNDelegate for add + data
             /                        \
  PNDelegate for int + data     PNDelegate for double + data
```
What will be in ```data```? In short: it will be result od method ```delegateData```. So we can:
```dart
dynamic delegateData(String delegateName, Map<String, dynamic> rawData) {
   //...
   if (delegateName == "int") {
      return rawData;
   }
   //...
}
```
Sure, this will work if your delegate will look like:
```dart
Action _intDelegate(dynamic context, dynamic data) {
  int value = int.tryParse(data["value"]);
  //.... do something with it
  return Action.proceed;
}
```
In this example data associated with int node is ```Map<String,dynamic>``` so every time we execute
processing tree we will do ```String``` to ```int``` conversion. Can we do it better? Yes, consider:
```dart
dynamic delegateData(String delegateName, Map<String, dynamic> rawData) {
   //...
   if (delegateName == "int") {
      return int.tryParse(data["value"]);
   }
   //...
}
```
Now our delegate can look like:
```dart
Action _intDelegate(dynamic context, dynamic data) {
  int value = data;
  //.... do something with it
  return Action.proceed;
}
```
There is one more thing... Each call to ```delegateData``` will have it own map, so it's perfectly fine
to return it if more data are collected from node. However you might want to preprocess this data in
map. Consider:
```xml
  <SomeXmlNode int="22" string="Some text" bool="true"/>
```
And some code to initial preprocess:
```dart
dynamic delegateData(String delegateName, Map<String, dynamic> rawData) {
   //...
   if (delegateName == "int") {
      rawData["int"] = int.tryParse(data["int"]);
      rawData["bool"] = "true" == data["bool"];
      return rawData
   }
   //...
}
```
And this is just a beginning... For more heavy magic read next section :)

### Using ```XmlTreeBuilder``` with ```BuildCoordinator```
There are two reasons why you are reading this. Curiosity or ```DelegateProvider``` is not enough...
Well let's meet his stronger brother ```BuildCoordinator```. All what is described for provider is true,
but a little different and with more details. Instead of two methods ```delegate``` and ```delegateData```
now there is one called ```requestData```. It has following responsibilities:
- return delegate to be used (same as ```DelegateProvider```)
- return data pack for delegate (same as ```DelegateProvider```)
- return type of node (covered later)
- optionally return any object you want. (covered later)
All those information should be returned in object ```ParsedItem```. The decision what to return can be
based on more more detailed info stored in input parameter of type ```State```. What is inside state:
- parentNodeName - name of xml element which owns currently processing xml node,
- delegateName - name of currently processing xml node
- constValDepth - how deep in branch of const values currently processing xml node is (covered later),
- isLeaf - if true then this xml node has no children
- data - data collected from xml node attributes (same as ```DelegateProvider```)
The idea behind returning delegate and data for it, is exactly this same as for ```DelegateProvider```.

### Item type, what is it?
In previous section there is something about return type of node, a lot of details can be found in
documentation for ```ParsedItemType```, it's important now to understands why it's introduced. It
appears that xml representation of algorithms contains some nodes which are just structured data
which need to be parsed, but doesn't need any delegate to execute/process it. So in short some xml
nodes can be "consumed" while parsing and not be part of processing tree. Quick example:
```xml
  <ShowText>
    <color value="red"/>
    <text value="text to show"/>
  </ShowText>
```
Looking at this you got impression that only element which do any action is ```ShowText```, other
elements are just constant data which need to be processed once and that's it. This is the real
reason why ```BuildCoordinator``` was introduced. So if ```text``` and ```color``` values should be
consumed while parsing, return ```ParsedItemType.constValue``` as an item type, otherwise if element
should be add to tree return ```ParsedItemType.owner```. That's it... almost... wait, should I return
delegate for ```constValue``` type node? Well... yes, but: This delegate will be called immediately
while parsing! Whoooaaa.. why? Let's look at this, consider building tree of ```Widget```:
```xml
  <ListView>
    <Text data="text to show"/>
  <ListView>
```
Let's assume both ```ListView``` and ```Text``` are ```Widget``s. If ```Text`` will be marked as
```constValue``` then we can process data for it, but we don't have ```Widget``` instance... Builder
doesn't understands what each xml node really means. Here comes delegate, it know what to do with data.
In the path of execution will be like:
1. Parse xml, found ```ListView```, call ```requestData``` on coordinator.
1. Coordinator returns delegate which can build ListView + info that this is ```ParsedItemType.owner```
1. Parse xml, found ```Text```, call ```requestData``` on coordinator.
1. Coordinator returns delegate which can build Text + info that this is ```ParsedItemType.constValue```
1. Parser see that this element is a ```ParsedItemType.constValue```, so call immediately delegate
returned be coordinator.
1. Delegate takes data from xml element ```Text``` build widget and returns it.
1. Parser got result from delegate, add this result to ListView data collection.

It look fuzzy, it look overcomplicated, and there lack of many details... You need to experiment to
understands this. The good news is: that's it! No. Just kidding. Here is more :D Keep reading.

### Mystery solved: what is ```extObj``` in ```ParsedItem```?
If you missed this explanation here it goes. Sometimes some extra actions need to be done **after**
parsing of all sub elements of current element. Here comes second override from ```BuildCoordinator```
called ```step```. This method is called several times while parsing xml element. When it's discovered
when processing of children begin and end, and when parsing is finalized. Each time as a parameter you
get ```ParsedItemType``` instance, but this can be not enough. Sometimes some extra data should be
associated with this parsing node. This is ```extObj``` returned from ```requestData```. This is anything
you like, it's transparent for builder and will not be cached anywhere. It's only referenced by
```ParsedItemType``` while parse process, later all ```ParsedItemType``` instances are disposed.

### Mystery solved: what is ```constValDepth``` in ```ParsedItem```?
This is easy :) Any const value element can have many children (each must be a const value). If there
is need to know if currently parsing Const Value typed element, and how deep in this branch parser is
read value of ```constValDepth```.

# Execution of processing tree (```TreeProcessor```)
Each builder in the end returns instance of ```TreeProcessor``` which can be used to execute tree.
There are two types of execution ```normal``` and ```inverted```. Since those method are significant
different more info about execution models are in next sections.

## Normal execution
By default each builder returns instance of ```TreeProcessor``` prepared to normal execution. Running
of tree is done through method called ```process```, it accepts one argument of any type. This method will
pass this argument to each delegate in processing tree as a first parameter. Then after executing of
delegate decision what to do next based on returned ```Action``` value is taken. Please refer to documentation
of type ```Action``` to understands what will happen for every value. In general normal execution is
considered as going from root down to each leaf visiting each node and it's delegate (Preorder Traversal).
This execution allow usage of all ```Action``` enum values. So it allows to mark place in tree and return
back to it for process again some branch, or it allows to repeat execution of current node.

## Inverted execution
Sometimes it's demanded to process tree from bottom to up, collecting values from lower layers and processing it.
To do so call ```inverted``` method on ```TreeProcessor```, as a result another instance of ```TreeProcessor```
is returned. This new instance will perform inverted tree execution after call to ```process```. What's the
difference? In inverted execution again each nodes will be visited but starting from the leaves. It's guaranteed
that each delegate for node which have more then one child, will be called after all of children was processed.
Order of visiting children is same as for normal node, but delegate is called after children are visited.

## I'm executing... where is my result?
Well this is complicated. In general there might be no result, all depends what your delegates really do.
But there is one special place to search for results. In class ```TreeProcessor``` method ```process```
takes one argument of any type. This is object which is passed to all delegates while executing tree,
it is called context in ```PNDelegate``` signature. So
```dart
TreeProcessor processor = builder.build(...);
ResultCollector result = ResultCollector();
processor.process(result);
//...

Action myDelegate(dynamic context, dynamic data) {
  ResultCollector result = context; //here you go!
  //... perform something
  result.addData(...);  //call, store, whatever
}
```

# Conclusion
Is it really possible to use anywhere? Maybe... Take look at
[Yet Another Layout Builder](https://github.com/TheTosters/YetAnotherLayoutBuilder) maybe it will succeed.

# Motivation
This library came to my mind after few weeks of working with [xml_layout](https://pub.dev/packages/xml_layout)
package. After understanding what it gives and how it works, I found few things which I didn't like and
decided to do it in my way. However after some thinking I decided to split my work for two parts. First
prepare some generic library which allows me to build and execute algorithms using it representation stored
in independent way. This lib is a result of this work.


