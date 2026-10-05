import 'dart:convert';

import 'package:flutter_qjs/flutter_qjs.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';

import 'DomSelector.dart';

class JsCheerio {
  late JavascriptRuntime runtime;
  final Map<int, Element?> _elements = {};
  int _elementKey = 0;

  JsCheerio(this.runtime);

  void init() {
    runtime.onMessage('load', (dynamic args) {
      final html = args[0];
      final doc = parse(html);
      _elementKey++;
      _elements[_elementKey] = doc.documentElement ?? doc.body;
      return _elementKey;
    });

    runtime.onMessage('element_call', (dynamic args) {
      final method = args[0] as String;
      final key = args[1] as int;
      final element = _elements[key];

      if (element == null) return null;

      final methodArgs = args.length > 2 ? args[2] : [];

      dynamic result;

      switch (method) {
        case 'text':
          result = element.text;
          break;
        case 'html':
        case 'innerHtml':
          result = element.innerHtml;
          break;
        case 'outerHtml':
          result = element.outerHtml;
          break;
        case 'addClass':
          element.classes.add(methodArgs[0]);
          break;
        case 'removeClass':
          element.classes.remove(methodArgs[0]);
          break;
        case 'hasClass':
          result = element.classes.contains(methodArgs[0]);
          break;
        case 'attr':
          result = element.attributes[methodArgs[0]] ?? '';
          break;
        case 'setAttr':
          element.attributes[methodArgs[0]] = methodArgs[1];
          break;
        case 'removeAttr':
          element.attributes.remove(methodArgs[0]);
          break;
        case 'val':
          result = element.attributes['value'] ?? '';
          break;
        case 'setVal':
          element.attributes['value'] = methodArgs[0];
          break;
        case 'children':
          final children = element.children;
          List<int> keys = [];
          for (var child in children) {
            _elementKey++;
            _elements[_elementKey] = child;
            keys.add(_elementKey);
          }
          result = jsonEncode(keys);
          break;
        case 'parent':
          final parent = element.parent;
          if (parent != null) {
            _elementKey++;
            _elements[_elementKey] = parent;
            result = _elementKey;
          }
          break;
        case 'find':
          final selector = methodArgs[0];
          final elements = element.select(selector);
          List<int> keys = [];
          for (var el in elements ?? []) {
            _elementKey++;
            _elements[_elementKey] = el;
            keys.add(_elementKey);
          }
          result = jsonEncode(keys);
          break;
        case 'first':
          final first = element.children.firstOrNull;
          if (first != null) {
            _elementKey++;
            _elements[_elementKey] = first;
            result = _elementKey;
          }
          break;
        case 'last':
          final last = element.children.lastOrNull;
          if (last != null) {
            _elementKey++;
            _elements[_elementKey] = last;
            result = _elementKey;
          }
          break;
        case 'next':
          final next = element.nextElementSibling;
          if (next != null) {
            _elementKey++;
            _elements[_elementKey] = next;
            result = _elementKey;
          }
          break;
        case 'prev':
          final prev = element.previousElementSibling;
          if (prev != null) {
            _elementKey++;
            _elements[_elementKey] = prev;
            result = _elementKey;
          }
          break;
        case 'append':
          final htmlToAppend = methodArgs[0];
          final newNodes = parse(htmlToAppend).children;
          for (var node in newNodes) {
            element.append(node);
          }
          break;
        case 'prepend':
          final htmlToPrepend = methodArgs[0];
          final newNodes = parse(htmlToPrepend).children;
          for (var node in newNodes.reversed) {
            element.insertBefore(node, element.firstChild);
          }
          break;
        case 'empty':
          element.children.clear();
          break;
        case 'remove':
          element.remove();
          break;
        default:
          result = 'Unsupported method: $method';
      }

      return result;
    });

    runtime.evaluate(r'''
class Element {
  constructor(key) {
    this._key = key;
  }

  _call(method, args = []) {
    return sendMessage("element_call", JSON.stringify([method, this._key, args]));
  }

  text() { return this._call("text"); }
  html() { return this._call("html"); }
  outerHtml() { return this._call("outerHtml"); }
  val() { return this._call("val"); }
  attr(name) { return this._call("attr", [name]); }
  hasClass(cls) { return this._call("hasClass", [cls]); }

  addClass(cls) { this._call("addClass", [cls]); return this; }
  removeClass(cls) { this._call("removeClass", [cls]); return this; }
  setAttr(name, value) { this._call("setAttr", [name, value]); return this; }
  removeAttr(name) { this._call("removeAttr", [name]); return this; }
  setVal(value) { this._call("setVal", [value]); return this; }

  append(html) { this._call("append", [html]); return this; }
  prepend(html) { this._call("prepend", [html]); return this; }
  empty() { this._call("empty"); return this; }
  remove() { this._call("remove"); return this; }

  children() {
    const keys = JSON.parse(this._call("children"));
    return new ElementCollection(keys.map(k => new Element(k)));
  }

  find(selector) {
    const keys = JSON.parse(this._call("find", [selector]));
    return new ElementCollection(keys.map(k => new Element(k)));
  }

  parent() {
    return new Element(this._call("parent"));
  }

  next() {
    return new Element(this._call("next"));
  }

  prev() {
    return new Element(this._call("prev"));
  }

  first() {
    return new Element(this._call("first"));
  }

  last() {
    return new Element(this._call("last"));
  }
}

class ElementCollection {
  constructor(elements) {
    this.elements = Array.isArray(elements) ? elements : (elements ? [elements] : []);
  }

  get length() {
    return this.elements.length;
  }

  size() {
    return this.elements.length;
  }

  text() {
    return this.elements.map(function(el) {
      if (typeof el === 'string') return el;
      if (el && typeof el.text === 'function') return el.text();
      return '';
    }).join("");
  }

  html() {
    const first = this.elements[0];
    if (first && typeof first.html === 'function') return first.html();
    return null;
  }

  outerHtml() {
    const first = this.elements[0];
    if (first && typeof first.outerHtml === 'function') return first.outerHtml();
    return null;
  }

  val() {
    const first = this.elements[0];
    if (first && typeof first.val === 'function') return first.val();
    return null;
  }

  attr(name) {
    const first = this.elements[0];
    if (first && typeof first.attr === 'function') return first.attr(name);
    return null;
  }

  hasClass(cls) {
    const first = this.elements[0];
    if (first && typeof first.hasClass === 'function') return first.hasClass(cls);
    return false;
  }

  each(fn) {
    for (let i = 0; i < this.elements.length; i++) {
      const el = this.elements[i];
      if (fn.call(el, i, el) === false) break;
    }
    return this;
  }

  map(fn) {
    const mapped = [];
    for (let i = 0; i < this.elements.length; i++) {
      const el = this.elements[i];
      const res = fn.call(el, i, el);
      if (res !== null && res !== undefined) {
        if (Array.isArray(res)) {
          mapped.push(...res);
        } else {
          mapped.push(res);
        }
      }
    }
    return new ElementCollection(mapped);
  }

  filter(fn) {
    return new ElementCollection(this.elements.filter(function (el, i) {
      try {
        return fn.call(el, i, el);
      } catch (_) {
        return false;
      }
    }));
  }

  addClass(cls) {
    this.elements.forEach(el => el && el.addClass && el.addClass(cls));
    return this;
  }

  removeClass(cls) {
    this.elements.forEach(el => el && el.removeClass && el.removeClass(cls));
    return this;
  }

  setAttr(name, value) {
    this.elements.forEach(el => el && el.setAttr && el.setAttr(name, value));
    return this;
  }

  removeAttr(name) {
    this.elements.forEach(el => el && el.removeAttr && el.removeAttr(name));
    return this;
  }

  setVal(value) {
    this.elements.forEach(el => el && el.setVal && el.setVal(value));
    return this;
  }

  append(html) {
    this.elements.forEach(el => el && el.append && el.append(html));
    return this;
  }

  prepend(html) {
    this.elements.forEach(el => el && el.prepend && el.prepend(html));
    return this;
  }

  empty() {
    this.elements.forEach(el => el && el.empty && el.empty());
    return this;
  }

  remove() {
    this.elements.forEach(el => el && el.remove && el.remove());
    return this;
  }

  find(selector) {
    const found = [];
    for (const el of this.elements) {
      if (el && typeof el._call === 'function') {
        try {
          const keys = JSON.parse(el._call("find", [selector]));
          if (Array.isArray(keys)) {
            for (const k of keys) found.push(new Element(k));
          }
        } catch (_) {}
      }
    }
    return new ElementCollection(found);
  }

  children(selector) {
    const children = [];
    for (const el of this.elements) {
      if (el && typeof el._call === 'function') {
        try {
          const keys = JSON.parse(el._call("children"));
          if (Array.isArray(keys)) {
            for (const k of keys) children.push(new Element(k));
          }
        } catch (_) {}
      }
    }
    const col = new ElementCollection(children);
    return selector ? col.filter(selector) : col;
  }

  parent() {
    const parents = [];
    for (const el of this.elements) {
      if (el && typeof el._call === 'function') {
        try {
          const key = el._call("parent");
          if (key) parents.push(new Element(key));
        } catch (_) {}
      }
    }
    return new ElementCollection(parents);
  }

  next() {
    const nextEls = [];
    for (const el of this.elements) {
      if (el && typeof el._call === 'function') {
        try {
          const key = el._call("next");
          if (key) nextEls.push(new Element(key));
        } catch (_) {}
      }
    }
    return new ElementCollection(nextEls);
  }

  prev() {
    const prevEls = [];
    for (const el of this.elements) {
      if (el && typeof el._call === 'function') {
        try {
          const key = el._call("prev");
          if (key) prevEls.push(new Element(key));
        } catch (_) {}
      }
    }
    return new ElementCollection(prevEls);
  }

  first() {
    return this.eq(0);
  }

  last() {
    return this.eq(-1);
  }

  eq(index) {
    const idx = +index;
    if (isNaN(idx)) return new ElementCollection([]);
    const actual = idx < 0 ? this.elements.length + idx : idx;
    if (actual < 0 || actual >= this.elements.length) {
      return new ElementCollection([]);
    }
    return new ElementCollection([this.elements[actual]]);
  }

  get(index) {
    if (index === undefined || index === null) {
      return this.elements.slice();
    }
    const idx = +index;
    if (isNaN(idx)) return undefined;
    const actual = idx < 0 ? this.elements.length + idx : idx;
    return this.elements[actual];
  }

  toArray() {
    return this.elements.slice();
  }

  [Symbol.iterator]() {
    return this.elements[Symbol.iterator]();
  }
}

class Stub {
  text() {
    return null;
  }
  html() {
    return null;
  }
  outerHtml() {
    return null;
  }
  val() {
    return null;
  }
  attr(name) {
    return null;
  }
  hasClass(cls) {
    return false;
  }
}

function load(html) {
  const rootKey = sendMessage("load", JSON.stringify([html]));
  const root = new Element(rootKey);

  const $ = function(input, context) {
    if (!input) {
      return new ElementCollection([]);
    }
    if (input instanceof ElementCollection) {
      return input;
    }
    if (input instanceof Element) {
      return new ElementCollection([input]);
    }
    if (Array.isArray(input)) {
      return new ElementCollection(
        input.map(x => (x instanceof Element ? x : (x && x._key ? new Element(x._key) : x)))
      );
    }
    if (typeof input === "string") {
      const trimmed = input.trim();
      if (trimmed.startsWith("<")) {
        try {
          const fragKey = sendMessage("load", JSON.stringify([trimmed]));
          return new ElementCollection([new Element(fragKey)]);
        } catch (_) {
          return new ElementCollection([]);
        }
      }
      const ctx = context ? $(context) : root;
      return ctx.find(input);
    }
    if (input && input._key) {
      return new ElementCollection([new Element(input._key)]);
    }
    return new ElementCollection([]);
  };

  $.html = function() {
    return root.html();
  };
  $.root = root;
  $.Element = Element;
  $.Collection = ElementCollection;

  return $;
}
  ''');
  }
}
