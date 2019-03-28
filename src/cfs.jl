abstract type ClosedForm end

struct PSolvClosedForm{T} <: ClosedForm
    func::T
    arg::T
    evec::Vector{T} # bases of exponentials
    xvec::Vector{T} # coeffs
    rvec::Vector{RationalFunction{T}} # rational functions
    fvec::Vector{Pair{FallingFactorial{T},FallingFactorial{T}}} # falling factorials
    # initvec::Vector{T}
    instance::T # instantiate closed form, yields a closed form where `arg` is replaced by `instance`
end

CFiniteClosedForm(rec.func, rec.arg, mvec, rvec, A \ b, b)

function CFiniteClosedForm(func::T, arg::T, roots::Vector{T}, mult::Vector{T}, coeffs::Vector{T}) where {T}
    
end

func(c::PSolvClosedForm) = c.func
arg(c::PSolvClosedForm) = c.arg
exponentials(c::PSolvClosedForm) = c.evec
coeffs(c::PSolvClosedForm) = c.xvec
rationalfunctions(c::PSolvClosedForm) = c.rvec
factorials(c::PSolvClosedForm) = c.fvec

Base.zero(c::PSolvClosedForm) = PSolvClosedForm(func(c), arg(c), [], [], [], [], arg(c))
Base.iszero(c::PSolvClosedForm) = isempty(exponentials(c)) && isempty(coeffs(c)) && isempty(rationalfunctions(c)) && isempty(factorials(c))

# ------------------------------------------------------------------------------

function Base.:*(c::PSolvClosedForm, x::Number)
    xvec = c.xvec * x
    PSolvClosedForm(c.func, c.arg, c.evec, c.rvec, c.fvec, xvec, c.instance)
end
Base.:*(x::Number, c::ClosedForm) = c * x

function Base.:+(c1::PSolvClosedForm{T}, c2::PSolvClosedForm{T}) where {T}
    @assert arg(c1) == arg(c2) "Argument mismatch, got $(arg(c1)) and $(arg(c1))"
    c1, c2 = reset(c1), reset(c2)
    evec = [c1.evec; c2.evec]
    rvec = [c1.rvec; c2.rvec]
    fvec = [c1.fvec; c2.fvec]
    xvec = [c1.xvec; c2.xvec]
    PSolvClosedForm(func(c1), arg(c1), evec, rvec, fvec, xvec, arg(c1))
end
Base.:-(c1::ClosedForm, c2::ClosedForm) where {T} = c1 + (-1) * c2

# ------------------------------------------------------------------------------

function (c::PSolvClosedForm{T})(n::Union{Int, T}) where {T}
    PSolvClosedForm(c.func, c.arg, c.evec, c.rvec, c.fvec, [subs(x, c.arg, n) for x in c.xvec], subs(c.instance, c.arg, n))
end

function reset(c::PSolvClosedForm{T}) where {T}
    if c.arg in free_symbols(c.instance)
        shift = c.instance - c.arg
        factors = [e^shift for e in c.evec]
        xvec = c.xvec .* factors
        evec = c.evec
    else
        xvec = c.xvec .* (c.evec .^ c.instance)
        evec = fill(one(T), length(c.rvec))
    end
    PSolvClosedForm(c.func, c.arg, evec, c.rvec, c.fvec, xvec, c.arg)
end

# ------------------------------------------------------------------------------

function rhs(::Type{T}, c::PSolvClosedForm{T}; expvars = nothing, factvars = nothing) where {T}
    n = c.instance
    exps = expvars
    if expvars == nothing
        exps = exponentials(c) .^ n
    end
    facts = factvars
    if factvars == nothing
        facts = factorials(c)
    end
    terms = zip(exps, coeffs(c), rationalfunctions(c), facts)
    sum(e * x * convert(T, r) * convert(T, f) for (e, x, r, f) in terms)
end

rhs(::Type{Expr}, c::PSolvClosedForm{T}) where {T} = convert(Expr, rhs(T, c))

function lhs(::Type{Expr}, c::ClosedForm)
    func = Symbol(string(c.func))
    arg = Symbol(string(c.instance))
    :($func($arg))
end

asfunction(c::ClosedForm) = :($(lhs(Expr, c)) = rhs(Expr, c))

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

function closedform(rec::CFiniteRecurrence{T}) where {T}

    # TODO: allow inhomogeneous recurrences?
    roots = Poly(coeffs(rec)) |> mroots
    # @info "Roots" roots

    size = order(rec)
    mvec = [T(i) for (_, m) in roots for i in 0:m - 1] # multiplicities
    rvec = [z for (z, m) in roots for _ in 0:m - 1] # roots
    @debug "Roots of characteristic polynomial" collect(zip(rvec, mvec))

    A = [i^m * r^i for i in 0:size-1, (r, m) in zip(rvec, mvec)]
    b = [initvar(rec.func, i) for i in 0:size - 1] 
    # @info "Ansatz" A b A\b
    CFiniteClosedForm(rec.func, rec.arg, mvec, rvec, A \ b, b)
end

function closedform(rec::HyperRecurrence{T}) where {T}
    hgterms = petkovsek(rec.coeffs, rec.arg)
    
    evec = T[]
    rvec = RationalFunction{T}[]
    fvec = Pair{FallingFactorial{T},FallingFactorial{T}}[]
    for (exp, rfunc, fact) in hgterms
        @debug "" exp rfunc fact
        push!(evec, exp)
        push!(rvec, rfunc)
        push!(fvec, fact)
    end

    size = order(rec)
    A = [e^i * r(i) * f[1](i) / f[2](i) for i in 0:size-1, (e, r, f) in zip(evec, rvec, fvec)]
    b = [initvar(rec.func, i) for i in 0:size - 1] 
    @info "" A b
    HyperClosedForm(rec.func, rec.arg, evec, rvec, fvec, A \ b, b)
end

# ------------------------------------------------------------------------------

init(c::CFiniteClosedForm, d::Dict) = CFiniteClosedForm(c.func, c.arg, c.mvec, c.rvec, [subs(x, d...) for x in c.xvec], c.initvec, c.instance)

init(c::HyperClosedForm, d::Dict) = HyperClosedForm(c.func, c.arg, c.evec, c.rvec, c.fvec, [subs(x, d...) for x in c.xvec], c.initvec, c.instance)

# ------------------------------------------------------------------------------

Base.show(io::IO, c::ClosedForm) = print(io, string(asfunction(c)))

function Base.show(io::IO, ::MIME"text/plain", c::ClosedForm)
    summary(io, c)
    println(io, ":")
    show(io, c)
end