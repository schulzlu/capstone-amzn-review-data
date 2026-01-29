{{ config(materialized='table') }}

select
    parent_asin,
    max(product_title) as product_title,
    max(seller) as seller,
    max(price) as price,

    count(*) as total_reviews,
    avg(user_rating) as avg_user_rating,

    sum(
        case when user_rating = 5 then 1 else 0 end
    ) as five_star_reviews,

    sum(
        case when user_rating = 1 then 1 else 0 end
    ) as one_star_reviews,

    sum(
        case
            when review_message is null or trim(review_message) = ''
            then 1 else 0
        end
    ) as reviews_without_message

from {{ ref('int_joined_product_data') }}
group by parent_asin
