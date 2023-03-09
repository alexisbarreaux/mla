#include<cstdlib>
#include<iostream>
#include<fstream>
using namespace std;
int main(int argc, char**argv){
    if(argc==1){
        cerr<<"Donner un nom de fichier à lire svp\n";
        return EXIT_FAILURE;
    }
    fstream fic(argv[1]);
    
    int  n;         //no sommets
    int  m;         //no arêtes
    int* b;         //demandes
    int**mat;       //matrice d'adjacence
    int* aretes[2]; //m arêtes, chacune avec deux sommets
    fic>>n;
    fic>>m;
    if(!fic.good()){
        cerr<<"Pb lecture "<<argv[1]<<endl;
        return EXIT_FAILURE;
    }
    b   = new int[n];
    mat = new int*[n];
    aretes[0] = new int[m];
    aretes[1] = new int[m];
    for(int i=0;i<n;i++){
        mat[i] = new int[n];
        for(int j=0;j<n;j++)
            mat[i][j] = 0;
        b[i] = 0;
    }
    for(int i=0;i<m;i++){
        int sommet1, sommet2;
        fic>>sommet1;
        fic>>sommet2;
        aretes[0][i] = sommet1;
        aretes[1][i] = sommet2;
        mat[sommet1][sommet2] = 1;    
        mat[sommet2][sommet1] = 1;    
    }
    for(int i=0;i<n;i++){                 //n demandes, la source est 0
        int sommet, demande;              
        fic>>sommet;
        fic>>demande;
        b[sommet] = demande;
    }
    //Fin lecture, affichage arêtes mat adjacence
    cout<<"n="<<n<<" sommets"<<endl;
    cout<<"m="<<m<<" arêtes"<<endl;
    for(int i=0;i<m;i++)
        cout<<"{"<<aretes[0][i]<<","<<aretes[1][i]<<"},";
    cout<<"\nMat adj:\n";
    for(int i=0;i<n;i++){
        for(int j=0;j<n;j++)
            cout<<mat[i][j];
        cout<<endl;
    }
    cout<<"Demandes:";
    for(int i=0;i<n;i++)
            cout<<i<<" veut "<<b[i]<<"; ";
    cout<<endl;
}
