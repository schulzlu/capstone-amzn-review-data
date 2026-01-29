with source as (

    select
        average_rating,
        parent_asin,
        price,
        rating_number,
        store,
        title
    from {{ source('glue_raw', 'meta_data') }}

),

validated as (

    select
        -- Parent ASIN: required business key
        nullif(trim(cast(parent_asin as varchar)), '') as parent_asin,

        -- Average rating: expected range 1–5
        case
            when average_rating between 1 and 5
                then cast(average_rating as decimal(3,2))
            else null
        end as average_rating,

        -- Number of ratings: must be non-negative
        case
            when rating_number is null then 0
            when rating_number >= 0
                then cast(rating_number as integer)
            else null
        end as number_of_ratings,

        -- Price: must be positive
        case
            when price > 0
                then cast(price as decimal(10,2))
            else null
        end as price,

        -- Seller/store name
        nullif(trim(cast(store as varchar)), '') as seller,

        -- Product title
        nullif(trim(cast(title as varchar)), '') as title

    from source

)

select *
from validated
