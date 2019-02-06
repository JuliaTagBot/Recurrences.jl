# module Petkovsek

# using SymPy

# export algpoly
import Base: convert, gcd
import SymPy.simplify

function fallingfactorial(x, j)
    result = Poly([1], string(x))
    for i in 0:j - 1
        result *= Poly([-i, 1], string(x))
    end
    return result
end

SymPy.degree(p::Sym, n::Sym) = SymPy.degree(Poly(p, n))

function symset(v::String, j::Int64)
    return Sym[Sym("$v$i") for i in 1:j]
end

denominator(s::SymPy.Sym) = denom(s)

function simplify(p::Poly)
    l = lcm2(denominator.(coeffs(p))...)
    Poly(coeffs(p) .* l, p.var)
end

function factors(expr::Sym)
    # c, list = factor_list(expr)
    # factor_list returns a Sym object instead of a tuple, does not seem to be right!
    c, list = factor_list(expr).x
    result = [x^y for (x,y) in list]
    # if c != 1
    #     push!(result, c)
    # end
    @debug "result" result
    return result
end

function shift(p::Poly{T}, s::Union{Int64, T}) where {T}
    c = T[polyval(polyder(p, i), s) / factorial(i) for i in 0:degree(p)]
    Poly(c, p.var)
end

function factors(p::Poly)
    sympoly = Sym(sprint(printpoly, p))
    facts = factors(sympoly)
    Poly.(SymPy.coeffs.(facts), p.var)
end

lc(p::Poly) = coeffs(p)[end]
coeff2(p::Poly, s::Int) = s <= degree(p) ? coeffs(p)[s+1] : 0


function algpoly(polylist::Vector{Poly{T}}, f::Poly{T}, n) where {T}
    @debug "algpoly" polylist
    # Construct polynomials qj that arise from treating the shift operator
	# as the difference operator plus the identity operator.
    qlist = []
    for j in 0:length(polylist)-1
        qj = 0
        for i in j:length(polylist)-1

            qj += (binomial(i, j) * polylist[i+1])

        end
        push!(qlist, qj)
    end

    # Find all candidates for the degree bound on output polynomial.
    b = maximum([(degree(poly) - (j - 1)) for (j, poly) in enumerate(qlist)])
    first = degree(f) - b
    second = -1 * b - 1
    lcoeffs = lc.(qlist)
    alpha = 0
    for j in 0:length(qlist)-1
        aux = degree(qlist[j+1]) - j
        if (degree(qlist[j+1]) - j) == b
            alpha += lcoeffs[j+1] * fallingfactorial(n, j)
        end
    end
    @debug "" alpha typeof(alpha)
    deg = mroots(alpha)
    deg = isa(deg, Dict) ? keys(deg) : deg
    third = maximum(deg)
    @debug "" qlist b deg first second third
    d = convert(Int64, max(first, second, third, 0))

    # Use method of undetermined coefficients to find the output polynomial.
    varlist = symset("a", d+1)
    # pol = 0 * n
    # for i in 0:d
    #     pol += n^i * varlist[i+1]
    # end
    genpoly = Poly(varlist, string(n))
    @debug "Generic polynomial" genpoly
    # solution = -1 * f
    # for (i, p) in enumerate(polylist)
    #     @debug "" shift(poly, i - 1) * p
    #     # solution += subs(pol, (n, n + (i-1))) * poly
    #     # @debug "" solution
    # end

    poly = sum(shift(genpoly, i - 1) * p for (i, p) in enumerate(polylist))
    poly -= f
    @debug "Poly" poly
    if iszero(poly)
        return T[1]
    end
    coefficients = coeffs(poly)
    filter!(e -> e != 0, coefficients)
    return values(SymPy.solve(coefficients, varlist)) |> collect
end

# function Base.convert(::Type{SymPy.Sym}, p::Poly{SymPy.Sym})

# end

Base.copysign(s::SymPy.Sym, i::Int64) = copysign(s, SymPy.Sym(i))
Base.copysign(s::SymPy.Sym, f::Float64) = copysign(s, SymPy.Sym(f))


function alghyper(polylist::Vector{Poly{T}}, n::T) where {T}
    @debug "-> alghyper" polylist n
    p = polylist[1]
    alist = factors(p)
    lcoeff = lc(p)

    # for (i,p) in enumerate(alist)
    #     alist[i] /= lcoeff
    # end
    if !(1 in alist)
        push!(alist, Poly([T(1)], string(n)))
    end

    d = length(polylist)
    p = shift(polylist[end], -d+2)
    lcoeff = lc(p)
    blist = factors(p)
    # for (i,p) in enumerate(blist)
    #     blist[i] /= lcoeff
    # end
    if !(1 in blist)
        push!(blist, Poly([T(1)], string(n)))
    end

    alist, blist = reverse(alist), reverse(blist)

    @debug "" alist blist

    solutions = []
    for aelem in alist
        for belem in blist
            @debug "Monic factors" aelem belem
            plist = []
            for i in 0:d-1 
                pi = polylist[i+1]
                for j in 0:i-1
                    pi *= shift(aelem, j)
                end
                for j in i:d-1
                    pi *= shift(belem, j)
                end
                push!(plist, pi)
            end

            m = maximum(degree.(plist))
            alpha = coeff2.(plist, m)
            @syms z
            zpol = 0*z
            for i in 0:length(alpha) - 1
                zpol += alpha[i+1]*z^i
            end

            vals = [key for (key,val) in polyroots(zpol) if key != 0]
            @debug "Roots" zpol vals
            for x in vals
                polylist2 = [x^(i-1)*p for (i,p) in enumerate(plist)]
                
                polysols = algpoly(polylist2, Poly(T[0], string(n)), n)
                if isempty(polysols)
                    continue
                end
                # polysols = collect(values(polysols))
                @debug "Solutions of algpoly" polysols

                filter!(e -> e != 0, polysols)
                if length(polysols) > 0
                    c = Poly(polysols, string(n))
                    s = x * (aelem // belem) * (shift(c, 1) // c)
                    @info "Solution" s
                    push!(solutions, s)
                end
            end
        end
    end
    return solutions
end

function convert(::Type{SymPy.Sym}, p::Poly)
    x = SymPy.Sym(string(p.var))
    sum(c*x^(i-1) for (i, c) in enumerate(coeffs(p)))
end
convert(::Type{Poly}, p::SymPy.Sym) = Poly(SymPy.coeffs(p))

function resultant(p::Poly, q::Poly)
    res = SymPy.resultant(convert(SymPy.Sym, p), convert(SymPy.Sym, q))
    convert(Poly, res)
end

function gcd(p::Poly{SymPy.Sym}, q::Poly{SymPy.Sym})
    res = SymPy.gcd(convert(SymPy.Sym, p), convert(SymPy.Sym, q))
    if !SymPy.has(res, SymPy.Sym(p.var))
        return Poly([res], p.var)
    end
    Poly(SymPy.coeffs(SymPy.Poly(res, SymPy.Sym(p.var))), p.var)
end

struct FallingFactorial{T}
    p::Poly{T}
    # exp::T
end

shift(f::FallingFactorial{T}, s::Union{Int64, T}) where {T} = FallingFactorial(shift(f.p, s))

function commonfactors(p::Poly, q::Poly)
    if p == 1 || q == 1
        return 1, (FallingFactorial(p), FallingFactorial(q))
    end
    k = variables(SymPy.Sym)
    res = resultant(shift(p, k), q)
    roots = keys(mroots(res)) |> collect
    filter!(x -> isinteger(x), roots)
    @debug "Integer roots of resultant" roots
    if isempty(roots)
        return 1, (FallingFactorial(p), FallingFactorial(q))
    end

    r = convert(Int64, roots[1])
    g = gcd(shift(p, r), q)
    @debug "GCD" g shift(p, r) q
    if r < 0
        @debug "" [polyval(g, i) for i in 1:-r]
        @debug "" [shift(g, i) for i in 1:-r]
        u = prod(polyval(g, i) for i in 1:-r)
        v = prod(shift(g, i) for i in 1:-r)
        rf = v // u 
    else
        @debug "" [polyval(g, -i+1) for i in 1:r]
        @debug "" [shift(g, -i+1) for i in 1:r]
        u = prod(polyval(g, -i+1) for i in 1:r)
        v = prod(shift(g, -i+1) for i in 1:r)
        rf = u // v
    end
    @debug "" u v rf

    s, sr = divrem(p, shift(g, -r))
    t, tr = divrem(q, g)
    if !iszero(sr) || !iszero(tr)
        @error "Remainder not zero (should not happen) - got $((sr, tr))"
    end
    rfunc, ffact = commonfactors(s, t)
    rfunc * rf, ffact
end

function hgterms(s::RationalFunction)
    c, num, den = monic(s)
    @debug "" c num den
    # fnum, fden = factors(num), factors(den)
    if num != 1 && den != 1
        # TODO: is this shift really the correct thing to do?!
        proots = keys(mroots(num)) |> collect
        qroots = keys(mroots(den)) |> collect
        pqroots = filter(x -> isinteger(x), [proots; qroots])
        @debug "" pqroots
        sh = isempty(pqroots) ? 0 : minimum(pqroots)
        sh = sh < 0 ? -sh : 0
        num, den = shift(num, sh), shift(den, sh)

        rfunc, ffact = commonfactors(num, den)
        rfunc, ffact = shift(rfunc, -sh), shift.(ffact, -sh)

        return c, rfunc, ffact
    end
    c, 1, (FallingFactorial(num), FallingFactorial(den))
end

function petkovsek(coeffs::Vector{T}, arg::T) where {T}
    coeffs = simplify.(coeffs)
    @debug "Petkovsek - input" coeffs
    ls = summands.(coeffs) |> Iterators.flatten
    ds = denom.(ls)
    val = lcm2(ds...)
    coeffs *= val
    coeffs = simplify.(coeffs)
    coeffs = SymPy.Poly.(coeffs, arg)
    hyper = alghyper(Poly.(SymPy.coeffs.(coeffs), string(arg)), arg)
    @debug "Petkovsek - alghyper" hyper
    hgterms.(hyper)
end

# function hyper()

# end # module

# using SymPy
# using Petkovsek

# @syms n y

# @syms n; Recurrences.petkovsek([2*n*(n+1), -(n^2 +3*n-2), n-1], n)

# # algpoly([3, -n, n-1], 0*n, n)
# # algpoly([n-1, -n, 3], 0*n, n)
# println("alghyper: ", [tohg(sol, n) for sol in alghyper([2*n*(n+1), -(n^2 +3*n-2), n-1], n)])
# println("algpoly: ", algpoly([n*(n + 1), -1*n^2 - 3*n + 2, 2*n - 2], 0*n,n))