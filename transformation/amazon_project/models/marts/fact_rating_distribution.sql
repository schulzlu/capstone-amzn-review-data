{{ config(materialized='table') }}

with product_ratings as (

    -- one row per product
    select
        parent_asin,
        round(avg_rating) as rating_bucket
    from {{ ref('fact_product_reviews') }}
)

select
    rating_bucket as rating,
    count(*) as number_of_products,
    round(
        count(*) * 100.0 / sum(count(*)) over (),
        2
    ) as pct_of_products
from product_ratings
where rating_bucket between 1 and 5
group by rating_bucket
order by rating_bucket
