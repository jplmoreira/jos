##############################################################################
#### Standard Class definition and its methods
##############################################################################
classes = Dict()

struct StandardClass
    name
    hierarchy::Array
    slots::Array
end

function make_class(name, hierarchy, slots)
	println(slots)
	expr = quote
		mutable struct $name
			$(slots...)
		end
	end
	global classes[name] = StandardClass(name, hierarchy, slots)
	eval(expr)
	return eval(name)
end

macro defclass(name, hierarchy, slots...)
    :( $(esc(name)) = make_class($(esc(QuoteNode(name))), $(esc(hierarchy)), $(esc([slots...]))) )
end

@defclass(C1, [], a)
@defclass(C2, [], b, c)
@defclass(C3, [C1, C2], d)

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

# Returns a list of pairs for the precedence of the received class
function get_local_precedence(class::StandardClass)
	let hierarchy = class.hierarchy, previous = hierarchy[1], local_precedence = [class=>previous,]
		for c in hierarchy[2:end]
			push!(local_precedence, previous=>c)
		end
		local_precedence
	end
end

# Returns a list of pairs for the precedence of the super-classes of a given class
function get_super_precedence(super_classes::Array)
	let precedence = []
		while length(super_classes) > 0
			class = splice!(super_classes, 1)
			hierarchy = class.hierarchy
			if length(hierarchy) > 0
				for super in hierarchy
					pair = class=>super
					if !(pair in precedence)
						push!(precedence, class=>super)
					end
					if !(super in precedence)
						push!(super_classes, super)
					end
				end
			elseif !((class=>false) in precedence)
				push!(precedence, class=>false) # N sei o que usar para substituir standard object
			end
		end
		precedence
	end
end

# Returns true if the received class has no predecessor on the received precedence pairs list
function no_predecessor(class::StandardClass, precedence::Array)
	for pair in precedence
		if pair.second == class
			return false
		end
	end
	true
end

# Returns a list of the classes with no predecessors on the received precedence pairs list
function get_no_predecessors(precedence::Array)
	let list = []
		for p in precedence
			class = p.first
			if (no_predecessor(class, precedence))
				push!(list, class)
			end
		end
		list
	end
end

# Returns the most specific class according to the received set of classes and its precedence pairs list
function get_most_specific(list::Array, precedence::Array)
	let predecessors = get_no_predecessors(precedence)
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
		end
	end
	println("Couldn't find most specific")
end

# Returns the precedence list of the received class, according to the CLOS topological sorting
function get_precedence_list(class::StandardClass)
	let sequence = get_super_sequence(class), precedence = [get_local_precedence(class)..., get_super_precedence(sequence[2:end])...],
		list = []
		while length(precedence) > 0
			specific = get_most_specific(list, precedence)
			push!(list, specific)
			index = 1
			while index <= length(precedence)
				if precedence[index].first == specific
					deleteat!(precedence, index)
				else
					index += 1
				end
			end
		end
		list
	end
end

##############################################################################
#### Standard Instance definition and its methods
##############################################################################

function make_instance(class, args...)
	values = Array{Int32}(undef, length(args))
	c = class(values...)
	for a in args
		setproperty!(c, a.first, a.second)
	end
	return c
end

c1i1 = make_instance(C1, :a=>2)
c2i1 = make_instance(C2, :b=>4, :c=>7)
c3i1 = make_instance(C3, :d=>1)
c3i2 = make_instance(C3, :d=>2)

println(c3i1)
println(c3i2)

function get_slot(obj, slot)
	return getproperty(obj, slot)
end

println(get_slot(c3i2, :d))

function set_slot!(obj, slot, value)
	setproperty!(obj, slot, value)
end

set_slot!(c3i2, :d, 5)
println(get_slot(c3i2, :d))

println(get_slot(c3i2, :d))
c3i2.d = 3
println(c3i2.d)
#println([get_slot(c3i1, s) for s in [:a, :b, :c]])
