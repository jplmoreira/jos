struct StandardClass
    name
    superclasses::Array
    slots::Array
end

make_class(name) = StandardClass(name, [], [])

macro defclass(name, s, sl)
    esc( :( $(name) = make_class($(QuoteNode(name))) ) )
end

@macroexpand @defclass(C1, [], [])

@defclass(C1, [], [])