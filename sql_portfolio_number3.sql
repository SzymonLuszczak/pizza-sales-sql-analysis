/* ============================================================================
   PROJEKT SQL: ANALIZA SPRZEDAŻY PIZZERII (Pizza Place Sales)
   Narzędzie i silnik: DBeaver + SQLite
   Szymon Luszczak
   Opis: Analiza przychodów, trendów czasowych oraz rentowności menu na bazie
         4 tabel relacyjnych (orders, order_details, pizzas, pizza_types).
   ============================================================================ */


/* ----------------------------------------------------------------------------
   1. PODSTAWOWE KPI BIZNESOWE
   Cel: Obliczenie łącznego przychodu, liczby zamówień, liczby sprzedanych pizz
        oraz średniej wartości koszyka (AOV - Average Order Value).
   ---------------------------------------------------------------------------- */
SELECT 
    COUNT(DISTINCT od.order_id) AS liczba_zamowien,
    SUM(CAST(od.quantity AS INTEGER)) AS sprzedane_pizze,
    ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS laczny_przychod,
    ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)) / COUNT(DISTINCT od.order_id), 2) AS sredni_koszyk_aov
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id;


/* ----------------------------------------------------------------------------
   2. SPRZEDAŻ WEDŁUG KATEGORII PIZZ (Udział w przychodzie %)
   Cel: Sprawdzenie, która kategoria menu generuje największy obrót i jaki ma
        procentowy udział w całej sprzedaży (wykorzystanie CTE i funkcji okna).
   ---------------------------------------------------------------------------- */
WITH przychod_kategorie AS (
    SELECT 
        pt.category AS kategoria,
        SUM(CAST(od.quantity AS INTEGER)) AS liczba_sztuk,
        ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS przychod
    FROM order_details od
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY pt.category
)
SELECT 
    kategoria,
    liczba_sztuk,
    przychod,
    ROUND(przychod * 100.0 / SUM(przychod) OVER(), 2) AS udzial_procentowy
FROM przychod_kategorie
ORDER BY przychod DESC;


/* ----------------------------------------------------------------------------
   3. ANALIZA ROZMIARÓW PIZZ
   Cel: Weryfikacja, które rozmiary (S, M, L, XL, XXL) cieszą się największym
        popytem i generują najwyższy przychód.
   ---------------------------------------------------------------------------- */
SELECT 
    p.size AS rozmiar,
    SUM(CAST(od.quantity AS INTEGER)) AS liczba_sztuk,
    ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS przychod
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
GROUP BY p.size
ORDER BY przychod DESC;


/* ----------------------------------------------------------------------------
   4. GODZINY SZCZYTU (Analiza obciążenia kuchni)
   Cel: Wyznaczenie godzin o największej liczbie zamówień w celu optymalizacji
        grafiku pracowników kuchni i dostawców.
   ---------------------------------------------------------------------------- */
SELECT 
    strftime('%H', o.time) AS godzina,
    COUNT(DISTINCT o.order_id) AS liczba_zamowien,
    SUM(CAST(od.quantity AS INTEGER)) AS liczba_pizz
FROM orders o
JOIN order_details od ON o.order_id = od.order_id
GROUP BY strftime('%H', o.time)
ORDER BY liczba_zamowien DESC;


/* ----------------------------------------------------------------------------
   5. TREND MIESIĘCZNY I ZMIANA MIESIĄC DO MIESIĄCA (MoM %)
   Cel: Analiza sezonowości sprzedaży oraz procentowej dynamiki przychodów
        względem poprzedniego miesiąca przy użyciu funkcji okna LAG().
   ---------------------------------------------------------------------------- */
WITH sprzedaz_miesieczna AS (
    SELECT 
        strftime('%Y-%m', o.date) AS miesiac,
        ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS przychod
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    GROUP BY strftime('%Y-%m', o.date)
)
SELECT 
    miesiac,
    przychod,
    LAG(przychod) OVER (ORDER BY miesiac) AS przychod_poprzedni_miesiac,
    ROUND((przychod - LAG(przychod) OVER (ORDER BY miesiac)) * 100.0 / LAG(przychod) OVER (ORDER BY miesiac), 2) AS zmiana_mom_proc
FROM sprzedaz_miesieczna
ORDER BY miesiac;


/* ----------------------------------------------------------------------------
   6. TOP 3 NAJLEPIEJ ZARABIAJĄCE PIZZE W KAŻDEJ KATEGORII
   Cel: Identyfikacja liderów sprzedaży wewnątrz każdej sekcji menu osobno
        przy użyciu funkcji okna DENSE_RANK() z partycjonowaniem po kategorii.
   ---------------------------------------------------------------------------- */
WITH sprzedaz_pizz AS (
    SELECT 
        pt.category AS kategoria,
        pt.name AS nazwa_pizzy,
        ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS przychod
    FROM order_details od
    JOIN pizzas p ON od.pizza_id = p.pizza_id
    JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
    GROUP BY pt.category, pt.name
),
ranking_pizz AS (
    SELECT 
        kategoria,
        nazwa_pizzy,
        przychod,
        DENSE_RANK() OVER (PARTITION BY kategoria ORDER BY przychod DESC) AS rnk
    FROM sprzedaz_pizz
)
SELECT 
    kategoria,
    nazwa_pizzy,
    przychod,
    rnk AS miejsce_w_kategorii
FROM ranking_pizz
WHERE rnk <= 3
ORDER BY kategoria, rnk;


/* ----------------------------------------------------------------------------
   7. NAJGORZEJ SPRZEDAJĄCE SIĘ PIZZE (Kandydaci do usunięcia z karty)
   Cel: Wskazanie 5 pozycji generujących najniższy przychód w celu uproszczenia
        menu i redukcji kosztów magazynowania rzadkich składników.
   ---------------------------------------------------------------------------- */
SELECT 
    pt.name AS nazwa_pizzy,
    pt.category AS kategoria,
    SUM(CAST(od.quantity AS INTEGER)) AS sprzedane_sztuki,
    ROUND(SUM(CAST(od.quantity AS INTEGER) * CAST(p.price AS REAL)), 2) AS przychod
FROM order_details od
JOIN pizzas p ON od.pizza_id = p.pizza_id
JOIN pizza_types pt ON p.pizza_type_id = pt.pizza_type_id
GROUP BY pt.name, pt.category
ORDER BY przychod ASC
LIMIT 5;
