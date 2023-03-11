# Rapport TP MLA

## Exercice 2

### Question 1

### Question 2

## Exercice 3

### Question 1

On peut remarquer dans la formulation initiale du problème que les contraintes d'inégalité sont en fait toutes saturées pour une solution optimale. Dans le cas où bnd = 1, pour faire transiter une quantité x (entière) il faut ouvrir exactement x liaisons et qui seront saturées. Ainsi pour ouvrir un minimum de liaisons il faut passer par un nombre minimum d'arêtes, cela revient à calculer les plus courts chemins entre la source et les terminaux. 

### Question 2

## Calculs de bornes

Dans le cas où la bande passante est strictement supérieure à 1 on peut exploiter la méthode avec Dijkstra (cas bnd = 1) pour obtenir des bornes inférieure et supérieure de notre problème.

En effet si on note V_b la valeur de l'objectif d'une instance donnée pour bnd = b, on a V_b >= ceil(V_1 / b), où ceil(x) est la partie entière supérieure de x.
Cela nous fait donc une borne inférieure du problème.

De plus, considérer uniquement les plus courts chemins pour faire transiter la demande est une solution réalisable du problème et calculer le coût correspondant nous permet d'obtenir une borne supérieure du problème.

Nous avons donc ajouter ses bornes dans le problème maître mais cela ne permet pas d'améliorer le temps de calcul pour toutes les instances. En effet sur certaines instances on réduit le temps et sur d'autres on l'augmente. Nous n'avons donc pas conservé ces bornes dans la comparaison des méthodes.

## Comparaisons des différentes méthodes