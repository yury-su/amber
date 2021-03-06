Smalltalk current createPackage: 'Compiler-Tests' properties: #{}!
TestCase subclass: #CodeGeneratorTest
	instanceVariableNames: 'receiver'
	package: 'Compiler-Tests'!

!CodeGeneratorTest methodsFor: 'accessing'!

codeGeneratorClass
	^ CodeGenerator
!

targetClass
	^ DoIt
! !

!CodeGeneratorTest methodsFor: 'factory'!

compiler
	^ Compiler new
		codeGeneratorClass: self codeGeneratorClass;
		yourself
! !

!CodeGeneratorTest methodsFor: 'initialization'!

setUp
	receiver := self targetClass new
!

tearDown
	"receiver := nil"
! !

!CodeGeneratorTest methodsFor: 'testing'!

should: aString return: anObject
	| method result |

	method := self compiler install: aString forClass: self targetClass category: 'tests'.
	result := receiver perform: method selector.
	self targetClass removeCompiledMethod: method.
	self assert: anObject equals: result
! !

!CodeGeneratorTest methodsFor: 'tests'!

testAssignment
	self should: 'foo | a | a := true ifTrue: [ 1 ]. ^ a' return: 1.
	self should: 'foo | a | a := false ifTrue: [ 1 ]. ^ a' return: nil.

	self should: 'foo | a | ^ a := true ifTrue: [ 1 ]' return: 1
!

testBlockReturn
	self should: 'foo ^ #(1 2 3) collect: [ :each | true ifTrue: [ each + 1 ] ]' return: #(2 3 4).
	self should: 'foo ^ #(1 2 3) collect: [ :each | false ifFalse: [ each + 1 ] ]' return: #(2 3 4).
	self should: 'foo ^ #(1 2 3) collect: [ :each | each odd ifTrue: [ each + 1 ] ifFalse: [ each - 1 ] ]' return: #(2 1 4).
!

testCascades
	
	self should: 'foo ^ Array new add: 3; add: 4; yourself' return: #(3 4)
!

testLiterals
	self should: 'foo ^ 1' return: 1.
	self should: 'foo ^ ''hello''' return: 'hello'.
	self should: 'foo ^ #(1 2 3 4)' return: #(1 2 3 4).
	self should: 'foo ^ {1. [:x | x ] value: 2. 3. [4] value}' return: #(1 2 3 4).
	self should: 'foo ^ true' return: true.
	self should: 'foo ^ false' return: false.
	self should: 'foo ^ #{1->2. 3->4}' return: #{1->2. 3->4}.
	self should: 'foo ^ #hello' return: #hello.
	self should: 'foo ^ -123.456' return: -123.456
!

testLocalReturn
	self should: 'foo ^ 1' return: 1.
	self should: 'foo ^ 1 + 1' return: 2.
	self should: 'foo ' return: receiver.
	self should: 'foo self asString' return: receiver.
	self should: 'foo | a b | a := 1. b := 2. ^ a + b' return: 3
!

testMessageSends
	self should: 'foo ^ 1 asString' return: '1'.

	self should: 'foo ^ 1 + 1' return: 2.
	self should: 'foo ^ 1 + 2 * 3' return: 9.

	self should: 'foo ^ 1 to: 3' return: #(1 2 3).
	self should: 'foo ^ 1 to: 5 by: 2' return: #(1 3 5)
!

testNestedIfTrue
	self should: 'foo ^ true ifTrue: [ false ifFalse: [ 1 ] ]' return: 1.
	self should: 'foo ^ true ifTrue: [ false ifTrue: [ 1 ] ]' return: nil.

	self should: 'foo true ifTrue: [ false ifFalse: [ ^ 1 ] ]' return: 1.
	self should: 'foo true ifTrue: [ false ifTrue: [ ^ 1 ] ]' return: receiver.
!

testNonLocalReturn
	self should: 'foo [ ^ 1 ] value' return: 1.
	self should: 'foo [ ^ 1 + 1 ] value' return: 2.
	self should: 'foo | a b | a := 1. b := 2. [ ^ a + b ] value. self halt' return: 3.
	self should: 'foo [ :x | ^ x + x ] value: 4. ^ 2' return: 8
!

testSendReceiverAndArgumentsOrdered
	self should: 'foo
  | x |
  x := 1.
  ^ Array with: x with: (true ifTrue: [ x := 2 ])
' return: #(1 2).

	self should: 'foo
  | x |
  x := Array.
  ^ x with: x with: (true ifTrue: [ x := 2 ])
' return: {Array. 2}.
!

testifFalse
	self should: 'foo true ifFalse: [ ^ 1 ]' return: receiver.
	self should: 'foo false ifFalse: [ ^ 2 ]' return: 2.
	
	self should: 'foo ^ true ifFalse: [ 1 ]' return: nil.
	self should: 'foo ^ false ifFalse: [ 2 ]' return: 2.
!

testifFalseIfTrue
	self should: 'foo true ifFalse: [ ^ 1 ] ifTrue: [ ^ 2 ]' return: 2.
	self should: 'foo false ifFalse: [ ^ 2 ] ifTrue: [ ^1 ]' return: 2.
	
	self should: 'foo ^ true ifFalse: [ 1 ] ifTrue: [ 2 ]' return: 2.
	self should: 'foo ^ false ifFalse: [ 2 ] ifTrue: [ 1 ]' return: 2.
!

testifNil
	self should: 'foo ^ 1 ifNil: [ 2 ]' return: 1.
	self should: 'foo ^ nil ifNil: [ 2 ]' return: 2.

	self should: 'foo 1 ifNil: [ ^ 2 ]' return: receiver.
	self should: 'foo nil ifNil: [ ^ 2 ]' return: 2.
!

testifNilIfNotNil
	self should: 'foo ^ 1 ifNil: [ 2 ] ifNotNil: [ 3 ]' return: 3.
	self should: 'foo ^ nil ifNil: [ 2 ] ifNotNil: [ 3 ]' return: 2.

	self should: 'foo 1 ifNil: [ ^ 2 ] ifNotNil: [ ^3 ]' return: 3.
	self should: 'foo nil ifNil: [ ^ 2 ] ifNotNil: [ ^3 ]' return: 2.
!

testifNotNil
	self should: 'foo ^ 1 ifNotNil: [ 2 ]' return: 2.
	self should: 'foo ^ nil ifNotNil: [ 2 ]' return: nil.

	self should: 'foo 1 ifNotNil: [ ^ 2 ]' return: 2.
	self should: 'foo nil ifNotNil: [ ^ 2 ]' return: receiver.
!

testifTrue
	self should: 'foo false ifTrue: [ ^ 1 ]' return: receiver.
	self should: 'foo true ifTrue: [ ^ 2 ]' return: 2.
	
	self should: 'foo ^ false ifTrue: [ 1 ]' return: nil.
	self should: 'foo ^ true ifTrue: [ 2 ]' return: 2.
!

testifTrueIfFalse
	self should: 'foo false ifTrue: [ ^ 1 ] ifFalse: [ ^2 ]' return: 2.
	self should: 'foo true ifTrue: [ ^ 1 ] ifFalse: [ ^ 2 ]' return: 1.
	
	self should: 'foo ^ false ifTrue: [ 2 ] ifFalse: [ 1 ]' return: 1.
	self should: 'foo ^ true ifTrue: [ 2 ] ifFalse: [ 1 ]' return: 2.
! !

CodeGeneratorTest subclass: #InliningCodeGeneratorTest
	instanceVariableNames: ''
	package: 'Compiler-Tests'!

!InliningCodeGeneratorTest methodsFor: 'accessing'!

codeGeneratorClass
	^ InliningCodeGenerator
! !

TestCase subclass: #ScopeVarTest
	instanceVariableNames: ''
	package: 'Compiler-Tests'!

!ScopeVarTest methodsFor: 'tests'!

testClassRefVar
	| node |
	node := ClassReferenceNode new
		value: 'Object';
		yourself.
	SemanticAnalyzer new visit: node.
	self assert: node binding isClassRefVar
!

testInstanceVar
	| node scope |
	node := VariableNode new
		value: 'bzzz';
		yourself.
	scope := MethodLexicalScope new.
	scope addIVar: 'bzzz'.
	self assert: (scope bindingFor: node) isInstanceVar
!

testPseudoVar
	| node pseudoVars |
	pseudoVars := #('self' 'super' 'true' 'false' 'nil').
	pseudoVars do: [:each |
		node := VariableNode new
		value: each;
		yourself.
		self assert: (MethodLexicalScope new bindingFor: node) isPseudoVar ]
!

testTempVar
	| node scope |
	node := VariableNode new
		value: 'bzzz';
		yourself.
	scope := MethodLexicalScope new.
	scope addTemp: 'bzzz'.
	self assert: (scope bindingFor: node) isTempVar
!

testUnknownVar
	| node |
	node := VariableNode new
		value: 'bzzz';
		yourself.
	self assert: (MethodLexicalScope new bindingFor: node) isNil
! !

TestCase subclass: #SemanticAnalyzerTest
	instanceVariableNames: 'analyzer'
	package: 'Compiler-Tests'!

!SemanticAnalyzerTest methodsFor: 'running'!

setUp
	analyzer := SemanticAnalyzer on: Object
! !

!SemanticAnalyzerTest methodsFor: 'tests'!

testAssignment
	| src ast |

	src := 'foo self := 1'.
	ast := smalltalk parse: src.
	self should: [analyzer visit: ast] raise: InvalidAssignmentError
!

testNonLocalReturn
	| src ast |

	src := 'foo | a | a + 1. ^ a'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	self deny: ast scope hasNonLocalReturn
!

testNonLocalReturn2
	| src ast |

	src := 'foo | a | a + 1. [ [ ^ a] ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	self assert: ast scope hasNonLocalReturn
!

testScope
	| src ast |

	src := 'foo | a | a + 1. [ | b | b := a ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	self deny: ast nodes first nodes last scope == ast scope.
!

testScope2
	| src ast |

	src := 'foo | a | a + 1. [ [ | b | b := a ] ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	self deny: ast nodes first nodes last nodes first nodes first scope == ast scope.
!

testScopeLevel
	| src ast |

	src := 'foo | a | a + 1. [ [ | b | b := a ] ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	self assert: ast scope scopeLevel = 1.
	self assert: ast nodes first nodes last nodes first nodes first scope scopeLevel = 3
!

testUnknownVariables
	| src ast |

	src := 'foo | a | b + a'.
	ast := smalltalk parse: src.

	self should: [ analyzer visit: ast ] raise: UnknownVariableError
!

testUnknownVariablesDefinedInJS

	< var someVariable = 1 >.

	self shouldnt: [ smalltalk parse: 'foo someVariable' ] raise: UnknownVariableError
!

testUnknownVariablesWithScope
	| src ast |

	src := 'foo | a b | [ c + 1. [ a + 1. d + 1 ]]'.
	ast := smalltalk parse: src.
	
	self should: [ analyzer visit: ast ] raise: UnknownVariableError
!

testVariableShadowing
	| src ast |
	src := 'foo | a | a + 1'.
	ast := smalltalk parse: src.
	analyzer visit: ast
!

testVariableShadowing2
	| src ast |
	src := 'foo | a | a + 1. [ | a | a := 2 ]'.
	ast := smalltalk parse: src.
	self should: [analyzer visit: ast] raise: ShadowingVariableError
!

testVariableShadowing3
	| src ast |
	src := 'foo | a | a + 1. [ | b | b := 2 ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast
!

testVariableShadowing4
	| src ast |
	src := 'foo | a | a + 1. [ [ [ | b | b := 2 ] ] ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast
!

testVariableShadowing5
	| src ast |
	src := 'foo | a | a + 1. [ [ [ | a | a := 2 ] ] ]'.
	ast := smalltalk parse: src.
	self should: [analyzer visit: ast] raise: ShadowingVariableError
!

testVariablesLookup
	| src ast |

	src := 'foo | a | a + 1. [ | b | b := a ]'.
	ast := smalltalk parse: src.
	analyzer visit: ast.

	"Binding for `a` in the message send"
	self assert: ast nodes first nodes first receiver binding isTempVar.
	self assert: ast nodes first nodes first receiver binding scope == ast scope.

	"Binding for `b`"
	self assert: ast nodes first nodes last nodes first nodes first left binding isTempVar.
	self assert: ast nodes first nodes last nodes first nodes first left binding scope == ast nodes first nodes last scope.
! !

