module PDFmerger

import Base.Filesystem
using Poppler_jll: pdfunite, pdfinfo

export merge_pdfs, append_pdf!

"""
```
  merge_pdfs(files::Vector{AbstractString}, destination::AbstractString = "merged.pdf";
                    cleanup::Bool = false)
```

Merge all pdf files in `files` into a pdf `destination`. Returns the name
 of the desintation file.

## Arguments

- `files`: array of file names to merge
- `destination`: name of the newly created pdf
- `cleanup`: if `true`, all `files` are deleted after merging
"""
function merge_pdfs(files::Vector{T}, destination::AbstractString="merged.pdf";
                    cleanup::Bool = false) where T <: AbstractString
    if destination ∈ files
        # rename existing file
        Filesystem.mv(destination, destination * "_x_")
        files[files .== destination] .=  destination * "_x_"
    end

    # Merge large number of files iteratively, because there
    # is a (OS dependent) limit how many files 'pdfunit' can handel at once.
    # See: https://gitlab.freedesktop.org/poppler/poppler/-/issues/334
    filemax = 200

    k = 1
    for files_part in Base.Iterators.partition(files, filemax)
        if k == 1
            outfile_tmp2 = "_temp_destination_$k"

            pdfunite() do unite
                run(`$unite $files_part $outfile_tmp2`)
            end
        else
            outfile_tmp1 = "_temp_destination_$(k-1)"
            outfile_tmp2 = "_temp_destination_$k"

            pdfunite() do unite
                run(`$unite $outfile_tmp1 $files_part $outfile_tmp2`)
            end
        end
        k += 1
    end

    # rename last file
    Filesystem.mv("_temp_destination_$(k-1)", destination, force=true)

    # remove temp files
    Filesystem.rm(destination * "_x_", force=true)
    Filesystem.rm.("_temp_destination_$(i)" for i in 1:(k-2))
    if cleanup
        Filesystem.rm.(files, force=true)
    end

    destination
end

merge_pdfs(file::AbstractString, destination::AbstractString="merged.pdf"; kwargs...) =
    merge_pdfs([file], destination; kwargs...)

"""
```
  append_pdf!(file1::AbstractString, file2::AbstractString;
              create::Bool = true, cleanup::Bool = false)
```

Appends the pdf `file2` to pdf `file1`.

## Arguments

- `create`: if `true`, `file1` is created if not existing.
- `cleanup`: if `true`, all `file2` is deleted after appending

## Example

Create a single pdf
containing many plots on separate pages:
```Julia
using Plots

for i in 1:5
    p = plot(rand(33));
    savefig(p, "temp.pdf")
    append_pdf!("allplots.pdf", "temp.pdf", cleanup=true)
end
```
"""
function append_pdf!(file1::AbstractString, file2::AbstractString;
                     create::Bool = true, cleanup::Bool = false)
    if Filesystem.isfile(file1)
        merge_pdfs([file1, file2], file1, cleanup=cleanup)
    else
        create || error("File '$file1' does not exist!")
        if cleanup
            Filesystem.mv(file2, file1)
        else
            Filesystem.cp(file2, file1)
        end
    end
end


"""
Count number of pages
"""
function n_pages(file)

    str = pdfinfo() do info
        read(`$info $file`, String)
    end

    m = match(r"Pages:\s+(?<npages>\d+)", str)
    isnothing(m) && error("Could not extract number of pages from:\n\n $str")
    parse(Int, m[:npages])
end

end
