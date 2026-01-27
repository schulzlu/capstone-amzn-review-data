with product_data as (
    select
        average_rating,
        parent_asin,
        price,
        rating_number as number_of_ratings,
        store as seller,
        title
    from {{ source('glue_raw', 'meta_data') }}
)

select * from product_data