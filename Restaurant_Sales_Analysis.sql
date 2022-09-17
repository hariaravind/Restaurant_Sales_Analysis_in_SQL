--1. What is the total amount each customer spent at the restaurant?
WITH CTE AS (
  SELECT
    s.customer_id as id,
    s.order_date,
    s.product_id,
    m.price
  FROM
    dannys_diner.sales s
    LEFT JOIN dannys_diner.menu m ON s.product_id = m.product_id
  ORDER BY
    1,
    2,
    3
)
SELECT
  DISTINCT c.id,
  SUM(price) OVER(
    PARTITION BY id
    ORDER BY
      id
  ) AS Total_Spent_by_Customer
FROM
  CTE c
ORDER BY
  1 --2. How many days has each customer visited the restaurant?
SELECT
  s.customer_id,
  COUNT(DISTINCT s.order_date) AS Num_of_Visits
FROM
  dannys_diner.sales s
GROUP BY
  1
ORDER BY
  1 --3. What was the first item from the menu purchased by each customer?
  WITH CTE AS (
    SELECT
      s.customer_id as id,
      s.order_date,
      s.product_id,
      m.product_name,
      m.price,
      RANK() OVER(
        PARTITION BY s.customer_id
        ORDER BY
          order_date
      ) AS RNK
    FROM
      dannys_diner.sales s
      LEFT JOIN dannys_diner.menu m ON s.product_id = m.product_id
    ORDER BY
      1,
      2,
      3
  )
SELECT
  id AS customer,
  product_name AS FIRST_ITEM
FROM
  CTE
WHERE
  RNK = 1 --4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
  s.product_id,
  m.product_name,
  COUNT(s.product_id)
FROM
  dannys_diner.sales s
  JOIN dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY
  1,
  2
ORDER BY
  3 DESC
LIMIT
  1 --5. Which item was the most popular for each customer?
  WITH CTE AS (
    SELECT
      s.customer_id as id,
      s.product_id,
      m.product_name as name,
      COUNT(s.product_id) OVER(PARTITION BY s.customer_id, s.product_id) AS Total_Each_Product
    FROM
      dannys_diner.sales s
      INNER JOIN dannys_diner.menu m ON s.product_id = m.product_id
  ),
  CTE2 AS (
    SELECT
      *,
      RANK() OVER(
        PARTITION BY id
        ORDER BY
          Total_Each_Product DESC
      ) AS RNK
    FROM
      CTE
  )
SELECT
  DISTINCT id,
  name
FROM
  CTE2
WHERE
  rnk = 1 --6. Which item was purchased first by the customer after they became a member?
  WITH CTE AS (
    SELECT
      s.customer_id,
      s.order_date,
      s.product_id,
      m.product_name,
      mm.join_date,
      ROW_NUMBER() OVER(
        PARTITION BY s.customer_id
        ORDER BY
          s.order_date
      ) AS RNK
    FROM
      dannys_diner.sales s
      JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
      JOIN dannys_diner.menu m ON s.product_id = m.product_id
    WHERE
      order_date >= join_date
    ORDER BY
      order_date
  )
SELECT
  customer_id,
  order_date,
  product_name
FROM
  CTE
WHERE
  RNK = 1 --7. Which menu item(s) was purchased just before the customer became a member and when?
  WITH CTE AS (
    SELECT
      s.customer_id,
      s.order_date,
      s.product_id,
      m.product_name,
      mm.join_date,
      RANK() OVER(
        PARTITION BY s.customer_id
        ORDER BY
          s.order_date DESC
      ) AS RNK
    FROM
      dannys_diner.sales s
      JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
      JOIN dannys_diner.menu m ON s.product_id = m.product_id
    WHERE
      order_date < join_date
    ORDER BY
      order_date
  )
SELECT
  customer_id,
  order_date,
  product_name
FROM
  CTE
WHERE
  RNK = 1
ORDER BY
  1,
  2,
  3 --8. What is the total items and amount spent for each member before they became a member?
  WITH CTE AS (
    SELECT
      s.customer_id,
      s.order_date,
      s.product_id,
      m.product_name,
      m.price,
      mm.join_date
    FROM
      dannys_diner.sales s
      JOIN dannys_diner.menu m ON s.product_id = m.product_id
      JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
    WHERE
      s.order_date < mm.join_date
    ORDER BY
      1,
      2
  )
SELECT
  customer_id,
  COUNT(DISTINCT product_id) AS Total_Unique_Items_Bought,
  SUM(price) AS Total_Spent
FROM
  CTE
GROUP BY
  customer_id --9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
  WITH CTE AS (
    SELECT
      s.customer_id,
      s.order_date,
      s.product_id,
      m.product_name,
      m.price,
      CASE
        WHEN s.product_id = 1 THEN price * 20
        ELSE price * 10
      END AS Points
    FROM
      dannys_diner.sales s
      JOIN dannys_diner.menu m ON s.product_id = m.product_id
    ORDER BY
      1,
      2
  )
SELECT
  customer_id,
  SUM(points) AS Total_Points
FROM
  CTE
GROUP BY
  1
ORDER BY
  2 DESC --10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
  WITH CTE AS (
    SELECT
      s.customer_id,
      s.order_date,
      s.product_id,
      m.product_name,
      m.price,
      CASE
        WHEN s.product_id = 1 THEN price * 20
        WHEN s.order_date BETWEEN mm.join_date
        AND DATEADD(
          day,
          7,
          mm.join_date :: DATE THEN price * 20
          ELSE price * 10
        END AS Points
        FROM
          dannys_diner.sales s
          JOIN dannys_diner.menu m ON s.product_id = m.product_id
          JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
        WHERE
          order_date <= '2021-01-31' :: DATE
        ORDER BY
          1,
          2
      )
    SELECT
      customer_id,
      SUM(points) AS Total_Points
    FROM
      CTE
    GROUP BY
      customer_id
    ORDER BY
      2 DESC --BONUS - 11. Recreate the table output using the available data with a binary field (Y/N) for Member/Non-Member at the time of the order.
    SELECT
      s.customer_id,
      s.order_date,
      m.product_name,
      m.price,
      CASE
        WHEN s.order_date < mm.join_date THEN 'N'
        WHEN mm.join_date IS NULL THEN 'N'
        ELSE 'Y'
      END AS Member
    FROM
      dannys_diner.sales s
      JOIN dannys_diner.menu m ON s.product_id = m.product_id
      LEFT JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
    ORDER BY
      1,
      2 --BONUS - 12. Create ranking for products purchased by customers who are members
      WITH CTE AS (
        SELECT
          s.customer_id,
          s.order_date,
          m.product_name,
          m.price,
          CASE
            WHEN s.order_date < mm.join_date THEN 'N'
            WHEN mm.join_date IS NULL THEN 'N'
            ELSE 'Y'
          END AS Member
        FROM
          dannys_diner.sales s
          JOIN dannys_diner.menu m ON s.product_id = m.product_id
          LEFT JOIN dannys_diner.members mm ON s.customer_id = mm.customer_id
        ORDER BY
          1,
          2
      )
    SELECT
      *,
      CASE
        WHEN Member = 'N' THEN null
        WHEN Member = 'Y' THEN RANK() OVER(
          PARTITION BY customer_id,
          Member
          ORDER BY
            order_date
        )
      END AS Ranking
    FROM
      CTE