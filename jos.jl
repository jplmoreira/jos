##############################################################################
#### Standard Class definition and its methods
##############################################################################

struct StandardClass
    name
    hierarchy::Array
    slots::Array
end

make_class(name, hierarchy, slots) = StandardClass(name, hierarchy, slots)

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
			[class=>false,]
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

mutable struct StandardInstance
	class::StandardClass
	slots::Dict
end

function make_instance(class::StandardClass, args...)
	isIn = true
	for a in args
		if !(a.first in class.slots)
			#println(a, " is roh roh with base class ", class.name)
			#println(a.first, " is not in ", class.slots)
			for h in class.hierarchy
				isIn = false
				if a.first in h.slots
					isIn = true
					#print(a.first, " is in ", h.slots)
					#println()
					break
				end
			end
			if !isIn
				println(a, " is roh roh with class ", class.name)
			end
		end
	end
	instance = StandardInstance(class, Dict(args))
	return instance
end

c3i1 = make_instance(C3, :a=>1, :b=>2, :c=>3, :d=>4)
c3i2 = make_instance(C3, :b=>2, :e=>23)

println(c3i1)
println(c3i2)

function get_slot(obj::StandardInstance, slot)
	return obj.slots[slot]
end

println(get_slot(c3i2, :b))

function set_slot!(obj::StandardInstance, slot, value)
	obj.slots[slot] = value
end

set_slot!(c3i2, :b, 3)

println(get_slot(c3i2, :b))
println([get_slot(c3i1, s) for s in [:a, :b, :c]])