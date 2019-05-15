struct StandardClass
    name
    hierarchy::Array
    slots::Array
end

make_class(name, hierarchy, slots) = StandardClass(name, hierarchy, slots)

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
				end
				index += 1
			end
		end
		list
	end
end

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

function no_predecessor(class::StandardClass, precedence::Array)
	for pair in precedence
		if pair.second == class
			return false
		end
	end
	true
end

function get_local_precedence(class::StandardClass)
	let hierarchy = class.hierarchy, previous = hierarchy[1], local_precedence = [class=>previous,]
		for c in hierarchy[2:end]
			push!(local_precedence, previous=>c)
		end
		local_precedence
	end
end

function get_super_precedence(super_classes::Array)
	let precedence = []
		while length(super_classes) > 0
			class = splice!(super_classes, 1)
			hierarchy = class.hierarchy
			if (length(hierarchy) > 0)
				for super in hierarchy
					push!(precedence, class=>super)
					push!(super_classes, super)
				end
			else
				push!(precedence, class=>false) # N sei o que usar para substituir standard object
			end
		end
		precedence
	end
end

function get_super_sequence(class::StandardClass)
	let sequence = [], classes = [class,]
		while length(classes) > 0
			c = splice!(classes, 1)
			hierarchy = c.hierarchy
			push!(sequence, c)
			classes = [classes..., hierarchy...]
		end
		sequence
	end
end

macro defclass(name, hierarchy, slots...)
    :( $(esc(name)) = make_class($(esc(QuoteNode(name))), $(esc(hierarchy)), $(esc([slots...]))) )
end

@macroexpand @defclass(C3, [C1, C2], c)

@defclass(C1, [], a)
@defclass(C2, [], b, c)
@defclass(C3, [C1, C2], d)

println(C1)

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
