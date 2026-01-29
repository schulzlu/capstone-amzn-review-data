{{ config(materialized='table') }}

select
    review_message,
    user_rating,
    number_of_helpful_votes,
    seller,
    product_title
from (
    select
        review_message,
        user_rating,
        number_of_helpful_votes,
        seller,
        product_title,
        row_number() over (
            partition by product_title
            order by number_of_helpful_votes desc
        ) as rn
    from {{ ref('int_joined_product_data') }}
) ranked
where rn <= 10
