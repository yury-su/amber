Smalltalk current createPackage: 'Compiler-IR' properties: #{}!
NodeVisitor subclass: #IRASTTranslator
	instanceVariableNames: 'source theClass method sequence nextAlias'
	package: 'Compiler-IR'!
!IRASTTranslator commentStamp!
I am the AST (abstract syntax tree) visitor responsible for building the intermediate representation graph.
I rely on a builder object, instance of IRBuilder.!

!IRASTTranslator methodsFor: 'accessing'!

method
	^ method
!

method: anIRMethod
	method := anIRMethod
!

nextAlias
	nextAlias ifNil: [ nextAlias := 0 ].
	nextAlias := nextAlias + 1.
	^ nextAlias asString
!

sequence
	^ sequence
!

sequence: anIRSequence
	sequence := anIRSequence
!

source
	^ source
!

source: aString
	source := aString
!

theClass
	^ theClass
!

theClass: aClass
	theClass := aClass
!

withSequence: aSequence do: aBlock
	| outerSequence |
	outerSequence := self sequence.
	self sequence: aSequence.
	aBlock value.
	self sequence: outerSequence.
	^ aSequence
! !

!IRASTTranslator methodsFor: 'visiting'!

alias: aNode
	| variable |

	aNode isImmutable ifTrue: [ ^ self visit: aNode ].

	variable := IRVariable new 
		variable: (AliasVar new name: '$', self nextAlias); 
		yourself.

	self sequence add: (IRAssignment new
		add: variable;
		add: (self visit: aNode);
		yourself).

	self method internalVariables add: variable.

	^ variable
!

temporallyDependentList: nodes
	| threshold result |
    threshold := 0.
    
    nodes withIndexDo: [ :each :i |
        (each shouldBeInlined or: [ each shouldBeAliased ])
		    ifTrue: [ threshold := i ]].

	result := OrderedCollection new.
	nodes withIndexDo: [ :each :i | 
		result add: (i <= threshold
			ifTrue: [ self alias: each ]
			ifFalse: [ self visit: each ])].

    ^result
!

visitAssignmentNode: aNode
	| left right assignment |
	right := self visit: aNode right.
	left := self visit: aNode left.
	self sequence add: (IRAssignment new 
		add: left;
		add: right;
		yourself).
	^ left
!

visitBlockNode: aNode
	| closure |
	closure := IRClosure new
		arguments: aNode parameters;
		scope: aNode scope;
		yourself.
	aNode scope temps do: [ :each |
		closure add: (IRTempDeclaration new 
			name: each name;
			yourself) ].
	aNode nodes do: [ :each | closure add: (self visit: each) ].
	^ closure
!

visitBlockSequenceNode: aNode
	^ self
		withSequence: IRBlockSequence new
		do: [ 
			aNode nodes ifNotEmpty: [
				aNode nodes allButLast do: [ :each | 
					self sequence add: (self visit: each) ].
				aNode nodes last isReturnNode 
					ifFalse: [ self sequence add: (IRBlockReturn new add: (self visit: aNode nodes last); yourself) ]
					ifTrue: [ self sequence add: (self visit: aNode nodes last) ]]]
!

visitCascadeNode: aNode
	| alias |

	aNode receiver isImmutable ifFalse: [ 
		alias := self alias: aNode receiver.
		aNode nodes do: [ :each |
			each receiver: (VariableNode new binding: alias variable) ]].

	aNode nodes allButLast do: [ :each |
		self sequence add: (self visit: each) ].

	^ self alias: aNode nodes last
!

visitDynamicArrayNode: aNode
	| array |
	array := IRDynamicArray new.
	aNode nodes do: [ :each | array add: (self visit: each) ].
	^ array
!

visitDynamicDictionaryNode: aNode
	| dictionary |
	dictionary := IRDynamicDictionary new.
	aNode nodes do: [ :each | dictionary add: (self visit: each) ].
	^ dictionary
!

visitJSStatementNode: aNode
	^ IRVerbatim new
		source: aNode source;
		yourself
!

visitMethodNode: aNode

	self method: (IRMethod new
		source: self source;
		arguments: aNode arguments;
		selector: aNode selector;
		messageSends: aNode messageSends;
		classReferences: aNode classReferences;
		scope: aNode scope;
		yourself).

	aNode scope temps do: [ :each |
		self method add: (IRTempDeclaration new
			name: each name;
			yourself) ].

	aNode nodes do: [ :each | self method add: (self visit: each) ].

	aNode scope hasLocalReturn ifFalse: [
		(self method add: IRReturn new) add: (IRVariable new
			variable: (aNode scope pseudoVars at: 'self');
			yourself) ].

	^ self method
!

visitReturnNode: aNode
	| return |
	return := aNode nonLocalReturn 
		ifTrue: [ IRNonLocalReturn new ]
		ifFalse: [ IRReturn new ].
	return scope: aNode scope.
	aNode nodes do: [ :each |
		return add: (self alias: each) ].
	^ return
!

visitSendNode: aNode
	| send all receiver arguments |
	send := IRSend new.
	send 
		selector: aNode selector;
		index: aNode index.
	aNode superSend ifTrue: [ send classSend: self theClass superclass ].
    
    all := self temporallyDependentList: { aNode receiver }, aNode arguments.
	receiver := all first.
	arguments := all allButFirst.

	send add: receiver.
	arguments do: [ :each | send add: each ].

	^ send
!

visitSequenceNode: aNode
	^ self 
		withSequence: IRSequence new 	
		do: [
			aNode nodes do: [ :each | | instruction |
				instruction := self visit: each.
				instruction isVariable ifFalse: [
					self sequence add: instruction ]]]
!

visitValueNode: aNode
	^ IRValue new 
		value: aNode value; 
		yourself
!

visitVariableNode: aNode
	^ IRVariable new 
		variable: aNode binding; 
		yourself
! !

Object subclass: #IRInstruction
	instanceVariableNames: 'parent instructions'
	package: 'Compiler-IR'!
!IRInstruction commentStamp!
I am the abstract root class of the IR (intermediate representation) instructions class hierarchy.
The IR graph is used to emit JavaScript code using a JSStream.!

!IRInstruction methodsFor: 'accessing'!

instructions
	^ instructions ifNil: [ instructions := OrderedCollection new ]
!

parent
	^ parent
!

parent: anIRInstruction
	parent := anIRInstruction
! !

!IRInstruction methodsFor: 'building'!

add: anObject
	anObject parent: self.
	^ self instructions add: anObject
!

remove
	self parent remove: self
!

remove: anIRInstruction
	self instructions remove: anIRInstruction
!

replace: anIRInstruction with: anotherIRInstruction
	anotherIRInstruction parent: self.
	self instructions 
		at: (self instructions indexOf: anIRInstruction)
		put: anotherIRInstruction
!

replaceWith: anIRInstruction
	self parent replace: self with: anIRInstruction
! !

!IRInstruction methodsFor: 'testing'!

canBeAssigned
	^ true
!

isClosure
	^ false
!

isInlined
	^ false
!

isLocalReturn
	^ false
!

isReturn
	^ false
!

isSend
	^ false
!

isSequence
	^ false
!

isTempDeclaration
	^ false
!

isVariable
	^ false
! !

!IRInstruction methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRInstruction: self
! !

!IRInstruction class methodsFor: 'instance creation'!

on: aBuilder
	^ self new
		builder: aBuilder;
		yourself
! !

IRInstruction subclass: #IRAssignment
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRAssignment methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRAssignment: self
! !

IRInstruction subclass: #IRDynamicArray
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRDynamicArray methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRDynamicArray: self
! !

IRInstruction subclass: #IRDynamicDictionary
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRDynamicDictionary methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRDynamicDictionary: self
! !

IRInstruction subclass: #IRScopedInstruction
	instanceVariableNames: 'scope'
	package: 'Compiler-IR'!

!IRScopedInstruction methodsFor: 'accessing'!

scope
	^ scope
!

scope: aScope
	scope := aScope
! !

IRScopedInstruction subclass: #IRClosure
	instanceVariableNames: 'arguments'
	package: 'Compiler-IR'!

!IRClosure methodsFor: 'accessing'!

arguments
	^ arguments ifNil: [ #() ]
!

arguments: aCollection
	arguments := aCollection
!

scope: aScope
	super scope: aScope.
	aScope instruction: self
!

sequence
	^ self instructions last
! !

!IRClosure methodsFor: 'testing'!

isClosure
	^ true
! !

!IRClosure methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRClosure: self
! !

IRScopedInstruction subclass: #IRMethod
	instanceVariableNames: 'source selector classReferences messageSends arguments internalVariables'
	package: 'Compiler-IR'!
!IRMethod commentStamp!
I am a method instruction!

!IRMethod methodsFor: 'accessing'!

arguments
	^ arguments
!

arguments: aCollection
	arguments := aCollection
!

classReferences
	^ classReferences
!

classReferences: aCollection
	classReferences := aCollection
!

internalVariables
	^ internalVariables ifNil: [ internalVariables := Set new ]
!

messageSends
	^ messageSends
!

messageSends: aCollection
	messageSends := aCollection
!

scope: aScope
	super scope: aScope.
	aScope instruction: self
!

selector
	^ selector
!

selector: aString
	selector := aString
!

source
	^ source
!

source: aString
	source := aString
! !

!IRMethod methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRMethod: self
! !

IRScopedInstruction subclass: #IRReturn
	instanceVariableNames: ''
	package: 'Compiler-IR'!
!IRReturn commentStamp!
I am a local return instruction.!

!IRReturn methodsFor: 'testing'!

canBeAssigned
	^ false
!

isBlockReturn
	^ false
!

isLocalReturn
	^ true
!

isNonLocalReturn
	^ self isLocalReturn not
!

isReturn
	^ true
! !

!IRReturn methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRReturn: self
! !

IRReturn subclass: #IRBlockReturn
	instanceVariableNames: ''
	package: 'Compiler-IR'!
!IRBlockReturn commentStamp!
Smalltalk blocks return their last statement. I am a implicit block return instruction.!

!IRBlockReturn methodsFor: 'testing'!

isBlockReturn
	^ true
! !

!IRBlockReturn methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRBlockReturn: self
! !

IRReturn subclass: #IRNonLocalReturn
	instanceVariableNames: ''
	package: 'Compiler-IR'!
!IRNonLocalReturn commentStamp!
I am a non local return instruction.
Non local returns are handled using a try/catch JS statement.

See IRNonLocalReturnHandling class!

!IRNonLocalReturn methodsFor: 'testing'!

isLocalReturn
	^ false
! !

!IRNonLocalReturn methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRNonLocalReturn: self
! !

IRInstruction subclass: #IRSend
	instanceVariableNames: 'selector classSend index'
	package: 'Compiler-IR'!
!IRSend commentStamp!
I am a message send instruction.!

!IRSend methodsFor: 'accessing'!

classSend
	^ classSend
!

classSend: aClass
	classSend := aClass
!

index
	^ index
!

index: anInteger
	index := anInteger
!

selector
	^ selector
!

selector: aString
	selector := aString
! !

!IRSend methodsFor: 'testing'!

isSend
	^ true
! !

!IRSend methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRSend: self
! !

IRInstruction subclass: #IRSequence
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRSequence methodsFor: 'testing'!

isSequence
	^ true
! !

!IRSequence methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRSequence: self
! !

IRSequence subclass: #IRBlockSequence
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRBlockSequence methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRBlockSequence: self
! !

IRInstruction subclass: #IRTempDeclaration
	instanceVariableNames: 'name'
	package: 'Compiler-IR'!
!IRTempDeclaration commentStamp!
I am a temporary variable declaration instruction!

!IRTempDeclaration methodsFor: 'accessing'!

name
	^ name
!

name: aString
	name := aString
! !

!IRTempDeclaration methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRTempDeclaration: self
!

isTempDeclaration
	^ true
! !

IRInstruction subclass: #IRValue
	instanceVariableNames: 'value'
	package: 'Compiler-IR'!
!IRValue commentStamp!
I am the simplest possible instruction. I represent a value.!

!IRValue methodsFor: 'accessing'!

value
	^value
!

value: aString
	value := aString
! !

!IRValue methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRValue: self
! !

IRInstruction subclass: #IRVariable
	instanceVariableNames: 'variable'
	package: 'Compiler-IR'!
!IRVariable commentStamp!
I am a variable instruction.!

!IRVariable methodsFor: 'accessing'!

variable
	^ variable
!

variable: aScopeVariable
	variable := aScopeVariable
! !

!IRVariable methodsFor: 'testing'!

isVariable
	^ true
! !

!IRVariable methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRVariable: self
! !

IRInstruction subclass: #IRVerbatim
	instanceVariableNames: 'source'
	package: 'Compiler-IR'!

!IRVerbatim methodsFor: 'accessing'!

source
	^ source
!

source: aString
	source := aString
! !

!IRVerbatim methodsFor: 'visiting'!

accept: aVisitor
	^ aVisitor visitIRVerbatim: self
! !

Object subclass: #IRVisitor
	instanceVariableNames: ''
	package: 'Compiler-IR'!

!IRVisitor methodsFor: 'visiting'!

visit: anIRInstruction
	^ anIRInstruction accept: self
!

visitIRAssignment: anIRAssignment
	^ self visitIRInstruction: anIRAssignment
!

visitIRBlockReturn: anIRBlockReturn
	^ self visitIRReturn: anIRBlockReturn
!

visitIRBlockSequence: anIRBlockSequence
	^ self visitIRSequence: anIRBlockSequence
!

visitIRClosure: anIRClosure
	^ self visitIRInstruction: anIRClosure
!

visitIRDynamicArray: anIRDynamicArray
	^ self visitIRInstruction: anIRDynamicArray
!

visitIRDynamicDictionary: anIRDynamicDictionary
	^ self visitIRInstruction: anIRDynamicDictionary
!

visitIRInlinedClosure: anIRInlinedClosure
	^ self visitIRClosure: anIRInlinedClosure
!

visitIRInlinedSequence: anIRInlinedSequence
	^ self visitIRSequence: anIRInlinedSequence
!

visitIRInstruction: anIRInstruction
	anIRInstruction instructions do: [ :each | self visit: each ].
	^ anIRInstruction
!

visitIRMethod: anIRMethod
	^ self visitIRInstruction: anIRMethod
!

visitIRNonLocalReturn: anIRNonLocalReturn
	^ self visitIRInstruction: anIRNonLocalReturn
!

visitIRNonLocalReturnHandling: anIRNonLocalReturnHandling
	^ self visitIRInstruction: anIRNonLocalReturnHandling
!

visitIRReturn: anIRReturn
	^ self visitIRInstruction: anIRReturn
!

visitIRSend: anIRSend
	^ self visitIRInstruction: anIRSend
!

visitIRSequence: anIRSequence
	^ self visitIRInstruction: anIRSequence
!

visitIRTempDeclaration: anIRTempDeclaration
	^ self visitIRInstruction: anIRTempDeclaration
!

visitIRValue: anIRValue
	^ self visitIRInstruction: anIRValue
!

visitIRVariable: anIRVariable
	^ self visitIRInstruction: anIRVariable
!

visitIRVerbatim: anIRVerbatim
	^ self visitIRInstruction: anIRVerbatim
! !

IRVisitor subclass: #IRJSTranslator
	instanceVariableNames: 'stream'
	package: 'Compiler-IR'!

!IRJSTranslator methodsFor: 'accessing'!

contents
	^ self stream contents
!

stream
	^ stream
!

stream: aStream
	stream := aStream
! !

!IRJSTranslator methodsFor: 'initialization'!

initialize
	super initialize.
	stream := JSStream new.
! !

!IRJSTranslator methodsFor: 'visiting'!

visitIRAssignment: anIRAssignment
	self visit: anIRAssignment instructions first.
	self stream nextPutAssignment.
	self visit: anIRAssignment instructions last.
!

visitIRClosure: anIRClosure
	self stream 
		nextPutClosureWith: [ super visitIRClosure: anIRClosure ] 
		arguments: anIRClosure arguments
!

visitIRDynamicArray: anIRDynamicArray
	self stream nextPutAll: '['.
	anIRDynamicArray instructions
		do: [ :each | self visit: each ]
		separatedBy: [ self stream nextPutAll: ',' ].
	stream nextPutAll: ']'
!

visitIRDynamicDictionary: anIRDynamicDictionary
	self stream nextPutAll: 'smalltalk.HashedCollection._fromPairs_(['.
		anIRDynamicDictionary instructions 
			do: [ :each | self visit: each ]
			separatedBy: [self stream nextPutAll: ',' ].
	self stream nextPutAll: '])'
!

visitIRMethod: anIRMethod
	self stream
		nextPutMethodDeclaration: anIRMethod 
		with: [ self stream 
			nextPutFunctionWith: [ 
				anIRMethod internalVariables notEmpty ifTrue: [
					self stream nextPutVars: (anIRMethod internalVariables asArray collect: [ :each |
						each variable alias ]) ].
				anIRMethod scope hasNonLocalReturn 
					ifTrue: [
						self stream nextPutNonLocalReturnHandlingWith: [
							super visitIRMethod: anIRMethod ]]
					ifFalse: [ super visitIRMethod: anIRMethod ]]
			arguments: anIRMethod arguments ]
!

visitIRNonLocalReturn: anIRNonLocalReturn
	self stream nextPutNonLocalReturnWith: [
		super visitIRNonLocalReturn: anIRNonLocalReturn ]
!

visitIRReturn: anIRReturn
	self stream nextPutReturnWith: [
		super visitIRReturn: anIRReturn ]
!

visitIRSend: anIRSend
	self stream nextPutAll: 'smalltalk.send('.
	self visit: anIRSend instructions first.
	self stream nextPutAll:  ',"', anIRSend selector asSelector, '",['.
	anIRSend instructions allButFirst
		do: [ :each | self visit: each ]
		separatedBy: [ self stream nextPutAll: ',' ].
	self stream nextPutAll: ']'.
	"anIRSend index > 1 
		ifTrue: [
			anIRSend classSend 
				ifNil: [ self stream nextPutAll: ',undefined' ]
				ifNotNil: [ self stream nextPutAll: ',', anIRSend classSend asJavascript ].
			self stream nextPutAll: ',', anIRSend index asString ]
		ifFalse: ["
			anIRSend classSend ifNotNil: [  
				self stream nextPutAll: ',', anIRSend classSend asJavascript ]"]".
	self stream nextPutAll: ')'
!

visitIRSequence: anIRSequence
	self stream nextPutSequenceWith: [
		anIRSequence instructions do: [ :each |
			self stream nextPutStatementWith: (self visit: each) ]]
!

visitIRTempDeclaration: anIRTempDeclaration
	self stream nextPutVar: anIRTempDeclaration name asVariableName
!

visitIRValue: anIRValue
	self stream nextPutAll: anIRValue value asJavascript
!

visitIRVariable: anIRVariable
	anIRVariable variable name = 'thisContext'
    	ifTrue: [ self stream nextPutAll: 'smalltalk.getThisContext()' ]
      	ifFalse: [ self stream nextPutAll: anIRVariable variable alias ]
!

visitIRVerbatim: anIRVerbatim
	self stream nextPutStatementWith: [
		self stream nextPutAll: anIRVerbatim source ]
! !

Object subclass: #JSStream
	instanceVariableNames: 'stream'
	package: 'Compiler-IR'!

!JSStream methodsFor: 'accessing'!

contents
	^ stream contents
! !

!JSStream methodsFor: 'initialization'!

initialize
	super initialize.
	stream := '' writeStream.
! !

!JSStream methodsFor: 'streaming'!

lf
	stream lf
!

nextPut: aString
	stream nextPut: aString
!

nextPutAll: aString
	stream nextPutAll: aString
!

nextPutAssignment
	stream nextPutAll: '='
!

nextPutClosureWith: aBlock arguments: anArray
	stream nextPutAll: '(function('.
	anArray 
		do: [ :each | stream nextPutAll: each asVariableName ]
		separatedBy: [ stream nextPut: ',' ].
	stream nextPutAll: '){'; lf.
	aBlock value.
	stream nextPutAll: '})'
!

nextPutFunctionWith: aBlock arguments: anArray
	stream nextPutAll: 'fn: function('.
	anArray 
		do: [ :each | stream nextPutAll: each asVariableName ]
		separatedBy: [ stream nextPut: ',' ].
	stream nextPutAll: '){'; lf.
	stream nextPutAll: 'var self=this;'; lf.
	aBlock value.
	stream nextPutAll: '}'
!

nextPutIf: aBlock with: anotherBlock
	stream nextPutAll: 'if('.
	aBlock value.
	stream nextPutAll: '){'; lf.
	anotherBlock value.
	stream nextPutAll: '}'
!

nextPutIfElse: aBlock with: ifBlock with: elseBlock
	stream nextPutAll: 'if('.
	aBlock value.
	stream nextPutAll: '){'; lf.
	ifBlock value.
	stream nextPutAll: '} else {'; lf.
	elseBlock value.
	stream nextPutAll: '}'
!

nextPutMethodDeclaration: aMethod with: aBlock
	stream 
		nextPutAll: 'smalltalk.method({'; lf;
		nextPutAll: 'selector: "', aMethod selector, '",'; lf;
		nextPutAll: 'source: ', aMethod source asJavascript, ',';lf.
	aBlock value.
	stream 
		nextPutAll: ',', String lf, 'messageSends: ';
		nextPutAll: aMethod messageSends asArray asJavascript, ','; lf;
          	nextPutAll: 'args: ', (aMethod arguments collect: [ :each | each value ]) asArray asJavascript, ','; lf;
		nextPutAll: 'referencedClasses: ['.
	aMethod classReferences 
		do: [:each | stream nextPutAll: each asJavascript]
		separatedBy: [stream nextPutAll: ','].
	stream 
		nextPutAll: ']';
		nextPutAll: '})'
!

nextPutNonLocalReturnHandlingWith: aBlock
	stream 
		nextPutAll: 'var $early={};'; lf;
		nextPutAll: 'try {'; lf.
	aBlock value.
	stream 
		nextPutAll: '}'; lf;
		nextPutAll: 'catch(e) {if(e===$early)return e[0]; throw e}'; lf
!

nextPutNonLocalReturnWith: aBlock
	stream nextPutAll: 'throw $early=['.
	aBlock value.
	stream nextPutAll: ']'
!

nextPutReturn
	stream nextPutAll: 'return '
!

nextPutReturnWith: aBlock
	self nextPutReturn.
	aBlock value
!

nextPutSendTo: receiver selector: selector arguments: arguments
	stream nextPutAll: 'smalltalk.send('.
	receiver emitOn: self. 
	stream nextPutAll: ',"', selector asSelector, '",['.
	arguments 
		do: [ :each | each emitOn: self ]
		separatedBy: [ stream nextPutAll: ',' ].
	stream nextPutAll: '])'
!

nextPutSequenceWith: aBlock
	"stream 
		nextPutAll: 'switch(smalltalk.thisContext.pc){'; lf."
	aBlock value.
	"stream 
		nextPutAll: '};'; lf"
!

nextPutStatement: anInteger with: aBlock
	stream nextPutAll: 'case ', anInteger asString, ':'; lf.
	self nextPutStatementWith: aBlock.
	stream nextPutAll: 'smalltalk.thisContext.pc=', (anInteger + 1) asString, ';'; lf
!

nextPutStatementWith: aBlock
	aBlock value.
	stream nextPutAll: ';'; lf
!

nextPutVar: aString
	stream nextPutAll: 'var ', aString, ';'; lf
!

nextPutVars: aCollection
	stream nextPutAll: 'var '.
	aCollection 
		do: [ :each | stream nextPutAll: each ]
		separatedBy: [ stream nextPutAll: ',' ].
	stream nextPutAll: ';'; lf
! !

!BlockClosure methodsFor: '*Compiler-IR'!

appendToInstruction: anIRInstruction
    anIRInstruction appendBlock: self
! !

!String methodsFor: '*Compiler-IR'!

asVariableName
	^ (Smalltalk current reservedWords includes: self)
		ifTrue: [ self, '_' ]
		ifFalse: [ self ]
! !

