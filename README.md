# Processing tree

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

Use ```TreeBuilder``` or ```StackedTreeBuilder``` builder to prepare structure of tree (please refer to
example) and binding with your code which will be executed while using tree. Finally call ```build```
function on builder to obtain instance of ```TreeProcessor```. From this moment tree is ready to
processing data call ```process`` function on obtained ```TreeProcessor``` instance to perform execution.

# Motivation
This library came to my mind after few weeks of working with [xml_layout](https://pub.dev/packages/xml_layout)
package. After understanding what it gives and how it works, I found few things which I didn't like and
decided to do it in my way. However after some thinking I decided to split my work for two parts. First
prepare some generic library which allows me to build and execute algorithms using it representation stored
in independent way. This lib is a result of this work.


