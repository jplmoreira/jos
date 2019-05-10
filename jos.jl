struct StandardClass
    name
    hierarchy::Array
    slots::Array
end

make_class(name, hierarchy, slots) = StandardClass(name, hierarchy, slots)

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
	instance = StandardInstance(class, Dict(args))
	return instance
end

c3i1 = make_instance(C3, :a=>1, :b=>2, :c=>3, :d=>4)
c3i2 = make_instance(C3, :b=>2)

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

