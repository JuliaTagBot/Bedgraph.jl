function _bump(records::AbstractVector{R}, b::Int) where {T, R<:Record{T}}

    new_records = Vector{R}(undef, length(records))

    for (i, record) in enumerate(records)
        new_record  = Record{T}(record.chrom, record.first + b, record.last + b, record.value)
        new_records[i] = new_record
    end

    return new_records
end

_bump_forward(records::AbstractVector{<:Record}) = _bump(records, 1)
_bump_back(records::AbstractVector{<:Record}) = _bump(records, -1)


function _range(record::Record; right_open=true)

    pos_start = right_open ? record.first : record.first + 1
    pos_end = right_open ? record.last - 1 : record.last

    return pos_start : pos_end
end


function _range(records::AbstractVector{<:Record}; right_open=true)

    pos_start = _range(records[1], right_open=right_open)[1]
    pos_end = _range(records[end], right_open=right_open)[end]

    return  pos_start : pos_end
end


function compress(chroms::AbstractVector{<:AbstractString}, n::AbstractVector{Int}, values::AbstractVector{T}; right_open = true, bump_back=true) where {T<:Real}

    ranges = Vector{UnitRange{Int}}()
    compressed_values = Vector{T}()
    compressed_chroms = Vector{String}()

    range_start = 1
    push!(compressed_values, values[1])

    for (index, value) in enumerate(values)
        if value != compressed_values[end]
            push!(ranges, n[range_start] : n[index - 1] )
            push!(compressed_values, value)
            push!(compressed_chroms, chroms[index])
            range_start = index
        end

        if index == length(values)
            push!(ranges, n[range_start] : n[index] )
            push!(compressed_values, value)
            push!(compressed_chroms, chroms[index])
        end
    end

    if right_open
        for (index, value) in enumerate(ranges)
            ranges[index] = first(value) : last(value) + 1
        end
    else
        for (index, value) in enumerate(ranges)
            ranges[index] = first(value) -1 : last(value)
        end
    end

    len = length(ranges)

    new_records = Vector{Record{T}}(undef, len)

    for (index, chrom, range, value) in zip(1:len, compressed_chroms, ranges, compressed_values)
        new_records[index]  = Record{T}(chrom, first(range), last(range), value)
    end

    return bump_back ? _bump_back(new_records) : new_records

end

compress(chrom::AbstractString, n::AbstractVector{Int}, values::AbstractVector{<:Real}; right_open = true, bump_back=true) = compress(fill(chrom, length(n)), n, values, right_open = right_open, bump_back = bump_back)


function expand(records::AbstractVector{R}; right_open=true, bump_forward=true) where {T, R<:Record{T}}

    #TODO: ensure records are sorted with no overlap.

    if bump_forward
        records =  _bump_forward(records)
    end

    total_range =_range(records, right_open = right_open)

    values = Vector{T}(undef, length(total_range))
    chroms = Vector{String}(undef, length(total_range))

    for record in records
        values[indexin(_range(record, right_open = right_open), total_range)] .= record.value
        chroms[indexin(_range(record, right_open = right_open), total_range)] .= record.chrom
    end

    return collect(total_range), values, chroms
end

expand(chrom::AbstractString, firsts::AbstractVector{Int}, lasts::AbstractVector{Int}, values::AbstractVector{<:Real}; right_open=true, bump_forward=true) = expand(fill(chrom, length(firsts)), firsts, lasts, values, right_open=right_open, bump_forward=bump_forward)
expand(chroms::AbstractVector{<:AbstractString}, firsts::AbstractVector{Int}, lasts::AbstractVector{Int}, values::Vector{<:Real}; right_open=true, bump_forward=true) = expand(Record.(chroms, firsts, lasts, values), right_open=right_open, bump_forward=bump_forward)
