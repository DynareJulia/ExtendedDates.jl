module ExtendedDates

using Reexport
@reexport using Dates

import Base: +, -, isfinite, isless, <, <=, :, print, show, ==, hash, convert, promote_rule, one
import Dates: Date, year, toms, days, _units, value, validargs, UTInstant
using RecipesBase: RecipesBase, @recipe

export period, frequency, subperiod, Undated,
    parse_periods,
    Semester, semesterofyear, dayofsemester, firstdayofsemester, lastdayofsemester,
    DaySE, WeekSE, MonthSE, QuarterSE, SemesterSE, YearSE, PeriodSE,
    PeriodsSinceEpoch

include("Semesters.jl")

const YearPeriod = Union{Month, Quarter, Semester, Year}

const EPOCH = Date(1) # Monday, January 1, year 1

# Constructors
"""
    period(::Type{<:Period}, year::Integer, subperiod::Integer = 1)

Construct a period from a year, subperiod, and frequency.

These periods are represented as an Int64 number of periods since an epoch defined by the
[`ExtendedDates.epoch`](@ref) function. For most period types the epoch is Saturday,
January 1, year 0. For week periods, it is Monday, January 3, year 0.

```jldoctest
julia> x = period(Semester, 2022, 1)
2022-S1

julia> Dates.format(x)
"2022-S1"

julia> Date(x)
2022-01-01

julia> Date(period(Week, 0))
0000-01-03

julia> Date(period(Day, 0))
0000-01-01
```
"""
period(::Type{P}, args...; kws...) where P <: Period = UTInstant{P}(args...; kws...)

function UTInstant{P}(year::Integer, subperiod::Integer = 1) where P <: Period
    err = validargs(P, year, subperiod)
    err === nothing || throw(err)
    return period(P, year, subperiod, nothing)
end

periodsinyear(P::Type{<:YearPeriod}) = Year(1) ÷ P(1)
UTInstant{P}(year, subperiod, unchecked::Nothing) where P <: Period =
    UTInstant(P(cld((Date(year) - EPOCH), P(1)) + subperiod))
UTInstant{P}(year, subperiod, unchecked::Nothing) where P <: YearPeriod  =
    UTInstant(P(periodsinyear(P) * (year - 1) + subperiod))
UTInstant{Day}(year, month, day::Number) = UTInstant(Day(value(Date(year, month, day))))

function validargs(P::Type{<:YearPeriod}, ::Int64, p::Int64)
    0 < p <= periodsinyear(P) || return ArgumentError("$P: $p out of range (1:$(periodsinyear(P)))")
    nothing
end
function validargs(::Type{Day}, y::Int64, p::Int64)
    0 < p <= daysinyear(y) || return ArgumentError("$P: $p out of range (1:$(daysinyear(P))) for $y")
    nothing
end
validargs(::Type{Day}, y::Int64, m::Int64, p::Int64) = validargs(Date, y, m, p)
function validargs(P::Type{<:Period}, y::Int64, p::Int64) # TODO inefficient
    year(Date(period(P, y, p, nothing))) == year(Date(period(P, y, 1, nothing))) || return ArgumentError("$P: $p out of range for $y")
    nothing
end

# Conversion to Date to calculate year and subperiod
Date(p::UTInstant{P}) where P <: Period = EPOCH + p.periods - frequency(p)

# Fallback accessors for frequency, year, subperiod
frequency(x) = oneunit(x)
frequency(::UTInstant{P}) where P = P(1)
frequency(::Type{UTInstant{P}}) where P = P(1)
"""
    year(::UTInstant{<:Period})

The year of a period.

```jldoctest
julia> year(period(Day, 1960, 12))
1960
```
"""
year(p::UTInstant{<:Period}) = year(Date(p))
"""
    year(::UTInstant{<:Period})

The subperiod of a period within a year. Numbering starts at one.

```jldoctest
julia> subperiod(period(Day, 1960, 12))
12

julia> Date(period(Day, 1960, 12))
1960-01-12
```
"""
subperiod(p::UTInstant{<:Period}) = fld((Date(p) - floor(Date(p), Year)), frequency(p)) + 1

# Avoid conversion to Date for Year based periods
year(p::UTInstant{<:YearPeriod}) = fld(p - oneunit(p), Year(1)) + year(EPOCH)
subperiod(p::UTInstant{<:YearPeriod}) = (rem(p - oneunit(p), Year(1), RoundDown)) ÷ frequency(p) + 1

#TODO move me:
one(p::UTInstant{<:Period}) = one(p.periods)
isless(a::UTInstant, b::UTInstant) = isless(a.periods-frequency(a), b.periods-frequency(b))
<(a::UTInstant, b::UTInstant) = a.periods <= b.periods-frequency(b)
==(a::UTInstant, b::UTInstant) = a.periods-frequency(a) == b.periods-frequency(b)
<=(a::UTInstant, b::UTInstant) = !(b < a)
+(i::UTInstant{P}, p::P) where P <: Period = UTInstant(i.periods + p)
-(i::UTInstant{P}, p::P) where P <: Period = UTInstant(i.periods - p)
isfinite(i::UTInstant{P}) where P <: Period = isfinite(i.periods) # true

value(p::UTInstant{P}) where P <: Period = value(p.periods)

const DaySE = UTInstant{Day}
const WeekSE = UTInstant{Week}
const MonthSE = UTInstant{Month}
const QuarterSE = UTInstant{Quarter}
const SemesterSE = UTInstant{Semester}
const YearSE = UTInstant{Year}
const PeriodSE = UTInstant{<:Period}

UTInstant{P}(s::AbstractString) where P <: Period = parse(UTInstant{P}, s)
UTInstant(s::AbstractString) = parse(UTInstant, s)

Base.print(io::IO, p::PeriodSE) = Dates.format(io, p)
Base.show(io::IO, ::MIME"text/plain", p::PeriodSE) = print(io, p)
Base.show(io::IO, p::UTInstant{P}) where P <: Period = print(io, P, "SE(\"", p, "\")")

const PeriodsSinceEpoch = Union{PeriodSE, Int64} # TODO rename me
# End TODO move me

const Undated = Int64

# Convenience function for range of periods
(:)(start::UTInstant{P}, stop::UTInstant{P}) where P <: Period = start:frequency(P):stop

# So that Day periods behave like Dates
Dates.month(d::UTInstant{Day}) = month(Date(d))
Dates.day(d::UTInstant{Day}) = day(Date(d))

include("io.jl")

@recipe f(::Type{Dates.UTInstant{P}}, t::Dates.UTInstant{P}) where P <: Period =
    (t -> Dates.value(t), t -> Dates.format(Dates.UTInstant(P(t))))

end
