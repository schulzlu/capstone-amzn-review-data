with reviews as (
    select
        helpful_vote,
        parent_asin,
        rating,
        text
    from {{ source('glue_raw', 'reviews') }}
)

select * from reviews