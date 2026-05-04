import numpy as np
import matplotlib.pyplot as plt

def fill_matrices(N):
    Q = np.clip(np.random.randn(N, N) * 2, -128, 128).astype(np.int8)
    K = np.clip(np.random.randn(N, N) * 2, -128, 128).astype(np.int8)

    return Q, K

def matmul_int8(Q, K):
    result = np.matmul(Q.astype(np.int32), K.T.astype(np.int32)) 
    return result

def int32_to_fp32(intTile):
    fpTile = intTile.astype(np.float32)
    return fpTile

def norm_fp32tile(fpTile, N):
    normTile = fpTile / (np.sqrt(N))
    return normTile

def online_softmax(normTile, N):
    sfmTile32 = np.zeros((N, N), dtype=np.float32)

    #find max
    for j in range(N):
        m = float('-inf')
        s = 0

        #iterate over the row
        for i in range(N):
            x = normTile[j, i]

            if x > m :
                s = s * np.exp(m - x) + np.exp(0)
                m = x
            else:
                s = s + np.exp(x - m)

        # Update normalized row
        for i in range(N):
            sfmTile32[j, i] = np.exp(normTile[j, i] - m) / s 
            
    return sfmTile32

def fp32_to_fp16 (sfmTile32):
    sfmTile = sfmTile32.astype(np.float16)
    return sfmTile



# Create files for tb verification
def save_files(Q, K, intTile, sfmTile):
    np.savetxt('Q.txt', Q, fmt='%6d')
    np.savetxt('K.txt', K, fmt='%6d')
    np.savetxt('intTile.txt', intTile, fmt='%6d')
    np.savetxt('sfmTile.txt', sfmTile, fmt='%f')

if __name__ == '__main__':
    # Fill matrices
    Q, K = fill_matrices(8)

    # Multiply matrices
    intTile = matmul_int8(Q, K)

    # Convert to fp32
    fpTile = int32_to_fp32(intTile)

    # Normalize
    normTile = norm_fp32tile(fpTile, 8)

    # Apply SoftMax
    sfmTile32 = online_softmax(normTile, 8)

    # Convert to fp16
    sfmTile = fp32_to_fp16(sfmTile32)

    # Create files
    save_files(Q, K, intTile, sfmTile)
