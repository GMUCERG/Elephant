/* Original c++ Code obtained from 
https://crypto.stackexchange.com/questions/47957/generate-anf-from-sbox
*/
#include <stdio.h>
#include <string.h>

int num_input_bits = 4; /* number of map input bits to consider */
int num_output_bits = 4; /* number of map output bits to consider */

/* black-box map function to extract ANF */
int map(int *sbox, int x)
{
  return sbox[x % 16];
}

int compute_anf_return_degree(int *sbox)
{
    size_t max_degree = 0;
    /* step 1) calculate ANF of the map function */
    int num_input_states = 1 << num_input_bits;
    for (int i = 0; i < num_output_bits; ++i)
    {
        int anf[16] = {0};
        for (int j = 0; j < num_input_states; ++j)
        {
            int bit = (map(sbox, j) >> i) & 1; /* extract map output bit */
            if (bit == 1)
            {
                for (int k = 0; k < num_input_states; ++k)
                { /* "broadcast" result to ANF terms */
                    if ((j & k) == j)
                    { /* does this bit contribute to this ANF term? */
                        anf[k] = (anf[k] + 1) % 2;
                    }
                }
            }
         }
        /* step 2) print the ANF expression */
        printf("y_%d = ",i);
        int term_count = 0;
        for (int j = 0; j < 16; ++j)
        {
            if (anf[j])
            {
                if (term_count++ != 0)
                {
                    printf(" + " );
                }
                size_t factor_count = 0;
                for (int k = 0; k < num_input_bits; ++k)
                {
                    if ((j >> k) & 1)
                    {
                        if (factor_count++ != 0)
                        {
                            printf("*");
                        }
                        printf("x_%d",k);
                    }
                }
                if (factor_count > max_degree)
                {
                    max_degree = factor_count;
                }
                if (factor_count == 0) {
                    printf("1");
                }
            }
        }
        if (term_count == 0)
        {
            printf("0");
        }
        printf("\n");
    }
    printf("degree %zu\n", max_degree);
}



//int main()
//{
//    int sbox[] = {0xE,0xD,0xB,0x0,0x2,0x1,0x4,0xF,0x7,0xA,0x8,0x5,0x9,0xC,0x3,0x6};
//    int degree = compute_anf_return_degree(sbox);
//    return 0;
//}
