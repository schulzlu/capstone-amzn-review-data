{{ config(materialized='table') }}

select
    parent_asin,
    product_title,

    sum(case when user_rating >= 4 then 1 else 0 end) as positive_reviews,
    sum(case when user_rating = 3 then 1 else 0 end) as neutral_reviews,
    sum(case when user_rating <= 2 then 1 else 0 end) as negative_reviews,

    round(
        sum(case when user_rating >= 4 then 1 else 0 end) * 100.0 / count(*),
        2
    ) as pct_positive_reviews

from {{ ref('int_joined_product_data') }}
group by parent_asin, product_title
