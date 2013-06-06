package h2d.comp;
import h2d.comp.CssEngine;

enum Token {
	TIdent( i : String );
	TString( s : String );
	TInt( i : Int );
	TFloat( f : Float );
	TDblDot;
	TSharp;
	TPOpen;
	TPClose;
	TExclam;
	TComma;
	TEof;
	TPercent;
	TSemicolon;
	TBrOpen;
	TBrClose;
	TDot;
	TSpaces;
	TSlash;
	TStar;
}

enum Value {
	VIdent( i : String );
	VString( s : String );
	VUnit( v : Float, unit : String );
	VFloat( v : Float );
	VInt( v : Int );
	VHex( v : String );
	VList( l : Array<Value> );
	VGroup( l : Array<Value> );
	VCall( f : String, vl : Array<Value> );
	VLabel( v : String, val : Value );
	VSlash;
}

class CssParser {

	var css : String;
	var s : Style;
	var simp : Style;
	var pos : Int;

	var spacesTokens : Bool;
	var tokens : Array<Token>;

	public function new() {
	}


	// ----------------- style apply ---------------------------

	#if debug
	function notImplemented( ?pos : haxe.PosInfos ) {
		haxe.Log.trace("Not implemented", pos);
	}
	#else
	inline function notImplemented() {
	}
	#end

	function applyStyle( r : String, v : Value, s : Style ) : Bool {
		switch( r ) {
		case "padding":
			var i = getVal(v);
			if( i != null ) { s.padding = i; return true; }
		case "width":
			var i = getVal(v);
			if( i != null ) {
				s.width = i;
				return true;
			}
		case "height":
			var i = getVal(v);
			if( i != null ) {
				s.height = i;
				return true;
			}
		case "background-color":
			var f = getFill(v);
			if( f != null ) {
				s.backgroundColor = f;
				return true;
			}
		case "background":
			return applyComposite(["background-color"], v, s);
		case "font-family":
			var l = getFontName(v);
			if( l != null ) {
				s.fontName = l;
				return true;
			}
		case "font-size":
			var i = getUnit(v);
			if( i != null ) {
				switch( i ) {
				case Pix(v):
					s.fontSize = v;
				default:
					notImplemented();
				}
				return true;
			}
		case "color":
			var c = getCol(v);
			if( c != null ) {
				s.color = c;
				return true;
			}
		case "border":
			return applyComposite(["border-width", "border-style", "border-color"], v, s);
		case "border-width":
			var i = getVal(v);
			if( i != null ) {
				s.borderSize = i;
				return true;
			}
		case "border-style":
			getIdent(v);
			// not supported
			return true;
		case "border-color":
			var c = getCol(v);
			if( c != null ) {
				s.borderColor = c;
				return true;
			}
		default:
			throw "Not implemented '"+r+"' = "+Std.string(v);
		}
		return false;
	}

	function applyComposite( names : Array<String>, v : Value, s : Style ) {
		var vl = switch( v ) {
		case VGroup(l): l;
		default: [v];
		};
		while( vl.length > 0 ) {
			var found = false;
			for( n in names ) {
				var count = switch( n ) {
				case "background-position": 2;
				default: 1;
				}
				if( count > vl.length ) count = vl.length;
				while( count > 0 ) {
					var v = (count == 1) ? vl[0] : VGroup(vl.slice(0, count));
					if( applyStyle(n, v, s) ) {
						found = true;
						names.remove(n);
						for( i in 0...count )
							vl.shift();
						break;
					}
					count--;
				}
				if( found ) break;
			}
			if( !found )
				return false;
		}
		return true;
	}

	function getGroup<T>( v : Value, f : Value -> Null<T> ) : Null<Array<T>> {
		switch(v) {
		case VGroup(l):
			var a = [];
			for( v in l ) {
				var v = f(v);
				if( v == null ) return null;
				a.push(v);
			}
			return a;
		default:
			var v = f(v);
			return (v == null) ? null : [v];
		}
	}

	function getList<T>( v : Value, f : Value -> Null<T> ) : Null<Array<T>> {
		switch(v) {
		case VList(l):
			var a = [];
			for( v in l ) {
				var v = f(v);
				if( v == null ) return null;
				a.push(v);
			}
			return a;
		default:
			var v = f(v);
			return (v == null) ? null : [v];
		}
	}
	
	function getInt( v : Value ) : Null<Int> {
		return switch( v ) {
		case VUnit(f, u):
			switch( u ) {
			case "px": Std.int(f);
			case "pt": Std.int(f * 4 / 3);
			default: null;
			}
		case VInt(v):
			Std.int(v);
		default:
			null;
		};
	}

	function getVal( v : Value ) : Null<Float> {
		return switch( v ) {
		case VUnit(f, u):
			switch( u ) {
			case "px": f;
			case "pt": f * 4 / 3;
			default: null;
			}
		case VInt(v):
			v;
		case VFloat(v):
			v;
		default:
			null;
		};
	}

	function getUnit( v : Value ) : Null<Unit> {
		return switch( v ) {
		case VUnit(f, u):
			switch( u ) {
			case "px": Pix(f);
			case "pt": Pix(f * 4 / 3);
			case "%": Percent(f / 100);
			default: null;
			}
		case VInt(v):
			Pix(v);
		case VFloat(v):
			Pix(v);
		default:
			null;
		};
	}

	function getIdent( v : Value ) : Null<String> {
		return switch( v ) {
		case VIdent(v): v;
		default: null;
		};
	}
	
	function getColAlpha( v : Value ) {
		var c = getCol(v);
		if( c != null && c >>> 24 == 0 )
			c |= 0xFF000000;
		return c;
	}
	
	function getFill( v : Value ) {
		var c = getColAlpha(v);
		if( c != null )
			return Color(c);
		switch( v ) {
		case VCall("gradient", [a, b, c, d]):
			var ca = getColAlpha(a);
			var cb = getColAlpha(b);
			var cc = getColAlpha(c);
			var cd = getColAlpha(d);
			if( ca != null && cb != null && cc != null && cd != null )
				return Gradient(ca, cb, cc, cd);
		default:
		}
		return null;
	}

	function getCol( v : Value ) : Null<Int> {
		return switch( v ) {
		case VHex(v):
			(v.length == 6) ? Std.parseInt("0x" + v) : ((v.length == 3) ? Std.parseInt("0x"+v.charAt(0)+v.charAt(0)+v.charAt(1)+v.charAt(1)+v.charAt(2)+v.charAt(2)) : null);
		case VIdent(i):
			switch( i ) {
			case "black":	0x000000;
			case "red": 	0xFF0000;
			case "lime":	0x00FF00;
			case "blue":	0x0000FF;
			case "white":	0xFFFFFF;
			case "aqua":	0x00FFFF;
			case "fuchsia":	0xFF00FF;
			case "yellow":	0xFFFF00;
			case "maroon":	0x800000;
			case "green":	0x008000;
			case "navy":	0x000080;
			case "olive":	0x808000;
			case "purple": 	0x800080;
			case "teal":	0x008080;
			case "silver":	0xC0C0C0;
			case "gray", "grey": 0x808080;
			default: null;
			}
		default:
			null;
		};
	}

	function getFontName( v : Value ) {
		return switch( v ) {
		case VString(s): s;
		case VGroup(_):
			var g = getGroup(v, getIdent);
			if( g == null ) null else g.join(" ");
		case VIdent(i): i;
		default: null;
		};
	}

	// ---------------------- generic parsing --------------------

	function unexpected( t : Token ) : Dynamic {
		throw "Unexpected " + Std.string(t);
		return null;
	}

	function expect( t : Token ) {
		var tk = readToken();
		if( tk != t ) unexpected(tk);
	}

	inline function push( t : Token ) {
		tokens.push(t);
	}

	function isToken(t) {
		var tk = readToken();
		if( tk == t ) return true;
		push(tk);
		return false;
	}

	public function parse( css : String, s : Style ) {
		this.css = css;
		this.s = s;
		pos = 0;
		tokens = [];
		parseStyle(TEof);
	}

	function valueStr(v) {
		return switch( v ) {
		case VIdent(i): i;
		case VString(s): '"' + s + '"';
		case VUnit(f, unit): f + unit;
		case VFloat(f): Std.string(f);
		case VInt(v): Std.string(v);
		case VHex(v): "#" + v;
		case VList(l):
			[for( v in l ) valueStr(v)].join(", ");
		case VGroup(l):
			[for( v in l ) valueStr(v)].join(" ");
		case VCall(f,args): f+"(" + [for( v in args ) valueStr(v)].join(", ") + ")";
		case VLabel(label, v): valueStr(v) + " !" + label;
		case VSlash: "/";
		}
	}
	
	function parseStyle( eof ) {
		while( true ) {
			if( isToken(eof) )
				break;
			var r = readIdent();
			expect(TDblDot);
			var v = readValue();
			var s = this.s;
			switch( v ) {
			case VLabel(label, val):
				if( label == "important" ) {
					v = val;
					if( simp == null ) simp = new Style();
					s = simp;
				}
			default:
			}
			if( !applyStyle(r, v, s) )
				throw "Invalid value " + valueStr(v) + " for css " + r;
			if( isToken(eof) )
				break;
			expect(TSemicolon);
		}
	}

	public function parseRules( css : String ) {
		this.css = css;
		pos = 0;
		tokens = [];
		var rules = [];
		while( true ) {
			if( isToken(TEof) )
				break;
			var classes = [];
			while( true ) {
				spacesTokens = true;
				isToken(TSpaces); // skip
				var c = readClass(null);
				spacesTokens = false;
				if( c == null ) break;
				classes.push(c);
				if( !isToken(TComma) )
					break;
			}
			if( classes.length == 0 )
				unexpected(readToken());
			expect(TBrOpen);
			this.s = new Style();
			this.simp = null;
			parseStyle(TBrClose);
			for( c in classes )
				rules.push( { c : c, s : s, imp : false } );
			if( this.simp != null )
				for( c in classes )
					rules.push( { c : c, s : simp, imp : true } );
		}
		return rules;
	}

	// ----------------- class parser ---------------------------

	function readClass( parent ) : CssClass {
		var c : CssClass = {
			parent : parent,
			node : null,
			id : null,
			className : null,
			pseudoClass : null,
		};
		var def = false;
		var last = null;
		while( true ) {
			var t = readToken();
			if( last == null )
				switch( t ) {
				case TStar: def = true;
				case TDot, TSharp, TDblDot: last = t;
				case TIdent(i): c.node = i; def = true;
				case TSpaces:
					return def ? readClass(c) : null;
				case TBrOpen, TComma:
					push(t);
					break;
				default:
					unexpected(t);
				}
			else
				switch( t ) {
				case TIdent(i):
					switch( last ) {
					case TDot: c.className = i; def = true;
					case TSharp: c.id = i; def = true;
					case TDblDot: c.pseudoClass = i; def = true;
					default: throw "assert";
					}
					last = null;
				default:
					unexpected(t);
				}
		}
		return def ? c : parent;
	}

	// ----------------- value parser ---------------------------

	function readIdent() {
		var t = readToken();
		return switch( t ) {
		case TIdent(i): i;
		default: unexpected(t);
		}
	}

	function readValue(?opt)  : Value {
		var t = readToken();
		var v = switch( t ) {
		case TSharp:
			VHex(readHex());
		case TIdent(i):
			VIdent(i);
		case TString(s):
			VString(s);
		case TInt(i):
			readValueUnit(i, i);
		case TFloat(f):
			readValueUnit(f, null);
		case TSlash:
			VSlash;
		default:
			if( !opt ) unexpected(t);
			push(t);
			null;
		};
		if( v != null ) v = readValueNext(v);
		return v;
	}

	function readHex() {
		var start = pos;
		while( true ) {
			var c = next();
			if( (c >= "A".code && c <= "F".code) || (c >= "a".code && c <= "f".code) || (c >= "0".code && c <= "9".code) )
				continue;
			pos--;
			break;
		}
		return css.substr(start, pos - start);
	}

	function readValueUnit( f : Float, ?i : Int ) {
		var t = readToken();
		return switch( t ) {
		case TIdent(i):
			VUnit(f, i);
		case TPercent:
			VUnit(f, "%");
		default:
			push(t);
			if( i != null )
				VInt(i);
			else
				VFloat(f);
		};
	}

	function readValueNext( v : Value ) : Value {
		var t = readToken();
		return switch( t ) {
		case TPOpen:
			switch( v ) {
			case VIdent(i):
				switch( i ) {
				case "url":
					readValueNext(VCall("url",[VString(readUrl())]));
				default:
					var args = switch( readValue() ) {
					case VList(l): l;
					case x: [x];
					}
					expect(TPClose);
					readValueNext(VCall(i, args));
				}
			default:
				push(t);
				v;
			}
		case TExclam:
			var t = readToken();
			switch( t ) {
			case TIdent(i):
				VLabel(i, v);
			default:
				unexpected(t);
			}
		case TComma:
			loopComma(v, readValue());
		default:
			push(t);
			var v2 = readValue(true);
			if( v2 == null )
				v;
			else
				loopNext(v, v2);
		}
	}

	function loopNext(v, v2) {
		return switch( v2 ) {
		case VGroup(l):
			l.unshift(v);
			v2;
		case VList(l):
			l[0] = loopNext(v, l[0]);
			v2;
		case VLabel(lab, v2):
			VLabel(lab, loopNext(v, v2));
		default:
			VGroup([v, v2]);
		};
	}

	function loopComma(v,v2) {
		return switch( v2 ) {
		case VList(l):
			l.unshift(v);
			v2;
		case VLabel(lab, v2):
			VLabel(lab, loopComma(v, v2));
		default:
			VList([v, v2]);
		};
	}

	// ----------------- lexer -----------------------

	inline function isSpace(c) {
		return (c == " ".code || c == "\n".code || c == "\r".code || c == "\t".code);
	}

	inline function isIdentChar(c) {
		return (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c == "-".code);
	}

	inline function isNum(c) {
		return c >= "0".code && c <= "9".code;
	}

	inline function next() {
		return StringTools.fastCodeAt(css, pos++);
	}

	function readUrl() {
		var c0 = next();
		while( isSpace(c0) )
			c0 = next();
		var quote = c0;
		if( quote == "'".code || quote == '"'.code ) {
			pos--;
			switch( readToken() ) {
			case TString(s):
				var c0 = next();
				while( isSpace(c0) )
					c0 = next();
				if( c0 != ")".code )
					throw "Invalid char " + String.fromCharCode(c0);
				return s;
			default: throw "assert";
			}

		}
		var start = pos - 1;
		while( true ) {
			if( StringTools.isEof(c0) )
				break;
			c0 = next();
			if( c0 == ")".code ) break;
		}
		return StringTools.trim(css.substr(start, pos - start - 1));
	}

	#if false
	function readToken( ?pos : haxe.PosInfos ) {
		var t = _readToken();
		haxe.Log.trace(t, pos);
		return t;
	}

	function _readToken() {
	#else
	function readToken() {
	#end
		var t = tokens.pop();
		if( t != null )
			return t;
		while( true ) {
			var c = next();
			if( StringTools.isEof(c) )
				return TEof;
			if( isSpace(c) ) {
				if( spacesTokens ) {
					while( isSpace(next()) ) {
					}
					pos--;
					return TSpaces;
				}

				continue;
			}
			if( isIdentChar(c) ) {
				var pos = pos - 1;
				do c = next() while( isIdentChar(c) );
				this.pos--;
				return TIdent(css.substr(pos,this.pos - pos).toLowerCase());
			}
			if( isNum(c) ) {
				var i = 0;
				do {
					i = i * 10 + (c - "0".code);
					c = next();
				} while( isNum(c) );
				if( c == ".".code ) {
					var f : Float = i;
					var k = 0.1;
					while( isNum(c = next()) ) {
						f += (c - "0".code) * k;
						k *= 0.1;
					}
					pos--;
					return TFloat(f);
				}
				pos--;
				return TInt(i);
			}
			switch( c ) {
			case ":".code: return TDblDot;
			case "#".code: return TSharp;
			case "(".code: return TPOpen;
			case ")".code: return TPClose;
			case "!".code: return TExclam;
			case "%".code: return TPercent;
			case ";".code: return TSemicolon;
			case ".".code: return TDot;
			case "{".code: return TBrOpen;
			case "}".code: return TBrClose;
			case ",".code: return TComma;
			case "*".code: return TStar;
			case "/".code:
				if( (c = next()) != '*'.code ) {
					pos--;
					return TSlash;
				}
				while( true ) {
					while( (c = next()) != '*'.code ) {
						if( StringTools.isEof(c) )
							throw "Unclosed comment";
					}
					c = next();
					if( c == "/".code ) break;
					if( StringTools.isEof(c) )
						throw "Unclosed comment";
				}
				return readToken();
			case "'".code, '"'.code:
				var pos = pos;
				var k;
				while( (k = next()) != c ) {
					if( StringTools.isEof(k) )
						throw "Unclosed string constant";
					if( k == "\\".code ) {
						throw "todo";
						continue;
					}
				}
				return TString(css.substr(pos, this.pos - pos - 1));
			default:
			}
			pos--;
			throw "Invalid char " + css.charAt(pos);
		}
		return null;
	}

}