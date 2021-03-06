import Base.getproperty
import Base.setproperty!

##############################################################################
#### Standard Class definition and its methods
##############################################################################

struct StandardClass
    name
    hierarchy::Array
    slots::Array
end

function make_class(name, hierarchy, slots)
	for class in hierarchy
		slots = vcat(slots, class.slots)
	end
	StandardClass(name, hierarchy, slots)
end

macro defclass(name, hierarchy, slots...)
    :( $(esc(name)) = make_class($(esc(QuoteNode(name))), $(esc(hierarchy)), $(esc([slots...]))) )
end

##############################################################################
#### Precedence list calculation (uses CLOS topological sorting)
##############################################################################

# Returns a list of all of the super-classes of the received class
function get_super_sequence(class::StandardClass)
	let sequence = [], classes = [class,]
		while length(classes) > 0
			c = splice!(classes, 1)
			hierarchy = c.hierarchy
			push!(sequence, c)
			classes = [classes..., hierarchy...]
			unique!(classes)
		end
		sequence
	end
end

# Returns a complete list of ordered pairs of the received set of classes
function get_ordered_pairs(sequence::Array)
	let set = []
		for class in sequence
			set = [set...,get_local_pairs(class)...]
		end
		unique!(set)
	end
end

# Returns a list of ordered pairs of the precedence of the received class
function get_local_pairs(class::StandardClass)
	let hierarchy = class.hierarchy
		if length(hierarchy) > 0
			previous = hierarchy[1]
			local_pairs = [class=>previous,]
			for c in hierarchy[2:end]
				push!(local_pairs, previous=>c)
				previous = c
			end
			local_pairs
		else
			[class=>nothing,]
		end
	end
end

# Returns true if the received class has no predecessor on the received pairs list
function no_predecessor(class::StandardClass, pairs::Array)
	for pair in pairs
		if pair.second == class
			return false
		end
	end
	true
end

# Returns a list of the classes with no predecessors on the received pairs list
function get_no_predecessors(pairs::Array)
	let list = []
		for pair in pairs
			class = pair.first
			if (no_predecessor(class, pairs))
				push!(list, class)
			end
		end
		list
	end
end

# Returns the most specific class according to the received set of classes and its precedence pairs list
function get_most_specific(predecessors::Array, list::Array)
	if length(predecessors) == 1
		return predecessors[1]
	else
		for class in reverse(list)
			for super in class.hierarchy
				if super in predecessors
					return super
				end
			end
		end
		error("Ordered pairs are inconsistent")
	end
end

# Returns the precedence list of the received class, according to the CLOS topological sorting
function get_precedence_list(class::StandardClass)
	let sequence = get_super_sequence(class), pairs = get_ordered_pairs(sequence),
		list = [], no_predecessor_classes = get_no_predecessors(pairs)
		while length(no_predecessor_classes) > 0
			specific = get_most_specific(no_predecessor_classes, list)
			push!(list, specific)
			filter!(x -> x != specific, sequence)
			filter!(x -> x.first != specific, pairs)
			no_predecessor_classes = get_no_predecessors(pairs)
		end
		if length(sequence) > 0
			error("The super-class set is inconsistent")
		end
		list
	end
end

##############################################################################
#### Standard Instance definition and its methods
##############################################################################

struct StandardInstance
	class::StandardClass
	slots::Dict{Symbol, Any}
end

function make_instance(class::StandardClass, args...)
	init = map(x -> x=>undef, class.slots)
	slots = Dict{Symbol, Any}(init)
	for s in args
		if haskey(slots, s.first)
			slots[s.first] = s.second
		else
			error("Slot $(s.first) is missing")
		end
	end
	instance = StandardInstance(class, slots)
end

# Altered get property function so that we can access to the slots using the '.'
function getproperty(obj::StandardInstance, f::Symbol)
	if haskey(getfield(obj, :slots), f)
		v = getfield(obj, :slots)[f]
		if v == undef
			error("Slot $f is unbound")
		else
			v
		end
	else
		error("Slot $f is missing")
	end
 end
setproperty!(obj::StandardInstance, f::Symbol, v) = getfield(obj, :slots)[f] = v

function get_slot(obj, slot)
	getproperty(obj, slot)
end

function set_slot!(obj, slot, value)
	setproperty!(obj, slot, value)
end

##############################################################################
#### Generic functions
##############################################################################

mutable struct GenericFunction
	name
	params::Array
	methods::Array
end

struct GenericMethod
	specializers::Array
	lambda
end

macro defgeneric(expr)
	if expr.head == :call
		name = expr.args[1]
		params = expr.args[2:end]
   		:( $(esc(name)) = GenericFunction($(esc(QuoteNode(name))), $(esc(params)), []) )
	else
		error("Can only define a function")
	end
end

macro defmethod(expr)
	if expr.head != :(=)
		error("Method definitions needs an assignment")
	else
		name = expr.args[1].args[1]
		specializers = map(x -> isa(x, Expr) ? x.args[1]=>x.args[2] : x=>nothing, expr.args[1].args[2:end])
		parameters = map(x -> isa(x,Expr) ? x.args[1] : x, expr.args[1].args[2:end])
		quote
			function lambda($(map(esc, parameters)...))
				$(esc(expr.args[2]))
			end
			make_method($(esc(name)), $(specializers), lambda)
		end
	end
end

# Adds a method to the generic function if the parameters of both are consistent. 
# If it exists, replaces the method with the same specializers
function make_method(generic, specializers, lambda)
	if length(generic.params) == length(specializers) &&
		generic.params == map(x -> x.first, specializers)
		filter!(x -> x.specializers != specializers, generic.methods)
		push!(generic.methods, GenericMethod(specializers, lambda))
	else
		error("Method parameters are not consistent with generic function")
	end
end

# Makes GenericFunction struct callable
# Verifies if the generic function call is correct
# Calls the best applicable method to the received arguments
function (g::GenericFunction)(args...)
	if length(g.methods) == 0
		error("No defined methods for generic function ", g.name)
	elseif length(args) != length(g.params)
		error("Generic function needs ", length(g.params), " argument(s)")
	elseif length(intersect(map(x -> isa(x, StandardInstance), args), false)) > 0
		error("Generic functions are only applicable to standard instances")
	else
		find_best_applicable_method(g.methods, args).lambda(args...)
	end
end

# Finds the best applicable method with the received argumetns
function find_best_applicable_method(methods::Array, args)
	println("applicable")
	let applicables = find_applicable_methods(methods, args)
		if length(applicables) == 0
			error("No applicable method")
		end
		applicables[1]
	end
end

# Returns all the applicable to the received args, these methods are sorted by specificity
function find_applicable_methods(methods::Array, args)
	let list = []
		for method in methods
			applicable = true
			index = 1
			while index <= length(args)
				name = method.specializers[index].second
				if name != nothing
					precedence = get_precedence_list(getfield(args[index], :class))
					names = map(x -> x.name, precedence)
					if !(name in names)
						applicable = false
						break
					end
				end
				index += 1
			end
			if applicable
				push!(list, method)
			end
		end
		sort(list, lt=(x,y)->is_more_specific(x, y, args))
	end	
end

# Sorting function for specificity of methods, according to the received arguments
function is_more_specific(m1::GenericMethod, m2::GenericMethod, args)
	let index = 1
		while index <= length(args)
			name1 = m1.specializers[index].second
			name2 = m2.specializers[index].second 
			if name1 != name2
				class = getfield(args[index], :class)
				precedence_list = map(x -> x.name, get_precedence_list(class))
				return findfirst(x -> x == name1, precedence_list) < findfirst(x -> x == name2, precedence_list)
			end
			index += 1
		end
	end
	true
end