with source as (

    select
        helpful_vote,
        parent_asin,
        rating,
        text
    from {{ source('glue_raw', 'reviews') }}

),

validated as (

    select
        -- Ensure helpful_vote is a non-negative integer
        case
            when helpful_vote is null then 0
            when helpful_vote < 0 then 0
            else cast(helpful_vote as integer)
        end as helpful_vote,

        -- Parent ASIN should always be present and trimmed
        nullif(trim(cast(parent_asin as varchar)), '') as parent_asin,

        -- Ratings are typically 1–5
        case
            when rating between 1 and 5 then cast(rating as integer)
            else null
        end as rating,

        -- Ensure text is a string, trim whitespace
        nullif(trim(cast(text as varchar)), '') as text

    from source

)

select *
from validated
