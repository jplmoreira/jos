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