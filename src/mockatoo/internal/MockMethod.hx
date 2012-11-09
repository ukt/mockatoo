package mockatoo.internal;
import mockatoo.exception.VerificationException;
import mockatoo.exception.StubbingException;
import mockatoo.Mockatoo;
import mockatoo.internal.MockOutcome;
import haxe.PosInfos;
using mockatoo.util.TypeEquality;

/**
Represents a single method in a Mock class, storing all calls, verifications
and stubs for that method.
Generated by <code>MockProxy</code> when mock is instanciated
*/
class MockMethod
{
	public var fieldName(default, null):String;

	var argumentTypes:Array<String>;

	public var returnType(default, null):Null<String>;

	var className:String;

	var invocations:Array<Array<Dynamic>>;
	var stubbings:Array<Stubbing>;

	public function new(className:String, fieldName:String, arguments:Array<String>, ?returns:String)
	{
		this.fieldName = fieldName;
		this.className = className;

		argumentTypes = arguments;
		returnType = returns;

		invocations = [];
		stubbings = [];
	}


	public function getOutcomeFor(args:Array<Dynamic>):MockOutcome
	{
		invocations.push(args);
		var stub = getStubbingForArgs(args);
		return getActiveStubValue(stub);
	}


	function getActiveStubValue(stub:Stubbing):MockOutcome
	{
		if(stub == null) return none;
		if(stub.values.length > 1)
			return stub.values.shift();//remove if not last one;
		return stub.values[0];
	} 


	public function addReturnFor<T>(args:Array<Dynamic>, values:Array<T>)
	{
		if(returnType == null) throw new StubbingException("Method [" + fieldName + "] has no return type and cannot stub custom return values.");

		var stub = getStubbingForArgs(args, true);

		if(stub == null)
		{
			stub = {args:args, values:[]};
			stubbings.push(stub);
		}

		for(value in values)
		{
			stub.values.push( returns(value) );
		}
	}


	public function addThrowFor(args:Array<Dynamic>, values:Array<Dynamic>)
	{
		var stub = getStubbingForArgs(args, true);

		if(stub == null)
		{
			stub = {args:args, values:[]};
			stubbings.push(stub);
		}

		for(value in values)
		{
			stub.values.push(throws(value));
		}
	}

	public function addCallbackFor(args:Array<Dynamic>, values:Array<Dynamic>)
	{
		var stub = getStubbingForArgs(args, true);

		if(stub == null)
		{
			stub = {args:args, values:[]};
			stubbings.push(stub);
		}

		for(value in values)
		{
			if(!Reflect.isFunction(value))
				 throw new StubbingException("Value [" + value + "] is not a function.");

			stub.values.push(calls(value));
		}
	}

	public function addDefaultStubFor(args:Array<Dynamic>)
	{
		var stub = getStubbingForArgs(args, true);

		if(stub == null)
		{
			stub = {args:args, values:[]};
			stubbings.push(stub);
		}
		stub.values.push(stubs);
	}

	public function addCallRealMethodFor(args:Array<Dynamic>)
	{
		var stub = getStubbingForArgs(args, true);

		if(stub == null)
		{
			stub = {args:args, values:[]};
			stubbings.push(stub);
		}
		stub.values.push(callsRealMethod);
	}

	function getStubbingForArgs(args:Array<Dynamic>, ?absoluteMatching:Bool = false):Stubbing
	{
		for(stub in stubbings)
		{
			if(stub.args.length != args.length) continue;

			if(stub.args.length == 0) return stub;

			var matchingArgs = 0;

			for(i in 0...args.length)
			{
				if(absoluteMatching) 
				{
					if(stub.args[i] == args[i] && Type.typeof(stub.args[i]) == Type.typeof(args[i]))
						matchingArgs ++;
				}
				else
				{
					if(compareArgs(stub.args[i],args[i])) 
						matchingArgs ++;
				}
			}

			if(matchingArgs == stub.args.length)
			{
				return stub;
			}
		}
		return null;
	}

	public function verify(mode:VerificationMode, ?args:Array<Dynamic>, ?pos:PosInfos):Bool
	{
		var matchingInvocations = getMatchingArgs(invocations, args);

		var matches:Int = matchingInvocations.length;
		
		var range:Range = null;
		//trace(fieldName + ":" + Std.string(mode) + ": " + Std.string(args) + ", " + count);
		switch(mode)
		{
			case times(value):
				range = new Range(value, value);
			case atLeastOnce:
				range = new Range(1, null);
			case never:
				range =  new Range(0, 0);
			case atLeast(value):
				range =  new Range(value, null);
			case atMost(value):
				range = new Range(null, value);
		}

		var execptionMessage:String = className + "." + fieldName + "(" + args.join(",") + ") was invoked " + toTimes(matches) + ", expected ";

		if(range.max == null)
		{
			if(matches >= range.min) return true;
			else throw new VerificationException(execptionMessage + "at least " + toTimes(range.min),pos);
		}
		else if(range.min == null)
		{
			 if(matches <= range.max) return true;
			 else throw new VerificationException(execptionMessage + "less than " + toTimes(range.max),pos);
		}
		else
		{
			if(matches == range.min) return true;
			else throw new VerificationException(execptionMessage + toTimes(range.min),pos);
		}
		
		return false;
	}

	function toTimes(value:Int):String
	{
		return value == 1 ? "[1] time" : "[" + value + "] times";
	}

	function getMatchingArgs(argArrays:Array<Array<Dynamic>>, args:Array<Dynamic>):Array<Array<Dynamic>>
	{
		var matches:Array<Array<Dynamic>> = [];

		for(targetArgs in argArrays)
		{

			if(targetArgs.length != args.length) 
			{
				continue;
			}

			var matchingArgs = 0;
			for(i in 0...args.length)
			{
				if(compareArgs(args[i], targetArgs[i])) 
					matchingArgs ++;
			}

			if(matchingArgs == args.length)
				matches.push(targetArgs);
		}

		return matches;
	}

	/**
	Compares to values to determine if they match.
	Supports fuzzy matching using <code>mockatoo.Matcher</code>
	*/
	function compareArgs(expected:Dynamic, actual:Dynamic):Bool
	{
		var type = Type.typeof(expected);
		switch(type)
		{
			case TUnknown:
			case TObject:
			case TNull:
				return actual == null;
			case TInt:
			case TFunction:
			case TFloat:
			case TEnum(e): //Enum<Dynamic>
				if(e == Matcher)
				{
					switch(expected)
					{
						case anyString: return Std.is(actual, String);
						case anyInt:  return Std.is(actual, Int);
						case anyFloat: return Std.is(actual, Float);
						case anyBool: return Std.is(actual, Bool);
						case anyIterator: return isIterable(actual);
						case anyObject: return isObject(actual);
						case anyEnum: return isEnumValueOf(actual, null);
						case enumOf(en): return isEnumValueOf(actual, en);
						case instanceOf(c): return Std.is(actual, c);
						case isNotNull: return actual != null;
						case isNull: return actual == null;
						case any: return true;
						case customMatcher(f): return f(actual);
					}
				}
			case TClass(c): //Class<Dynamic>
			case TBool:
		}
		return expected.equals(actual);
	}

	function isEnumValueOf(value:Dynamic, ?ofType:Enum<Dynamic>):Bool
	{
		switch(Type.typeof(value))
		{
			case TEnum(e): //Enum<Dynamic>
				if(ofType == null)
					return true;
				return e == ofType;
			default: return false;
		}
	}

	function isObject(value:Dynamic):Bool
	{
		switch(Type.typeof(value))
		{
			case TObject: return true;
			default: return false;
		}
	}

	function isIterable(value:Dynamic):Bool
	{
		if(value == null) return false;
		
		if(Std.is(value, Array) || Std.is(value, Hash) || Std.is(value, IntHash)) return true;

		//Iterable
		var iterator = Reflect.field(value, "iterator");
		
		if(Reflect.isFunction(iterator)) return true;

		//Iterator

		var next = Reflect.field(value, "next");
		var hasNext = Reflect.field(value, "hasNext");

		return Reflect.isFunction(next) && Reflect.isFunction(hasNext);

	}
}


typedef Stubbing = 
{
	args:Array<Dynamic>,
	values:Array<MockOutcome>
}


private class Range
{

	public var min:Null<Int>;
	public var max:Null<Int>;

	public function new(min:Null<Int>, max:Null<Int>)
	{
		this.min = min;
		this.max = max;
	}
}