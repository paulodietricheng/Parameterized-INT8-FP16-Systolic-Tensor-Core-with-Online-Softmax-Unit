import numpy as np
import matplotlib.pyplot as plt

# ------------------------------------------------------------
# Simulate realistic quantized attention tensors
# ------------------------------------------------------------
def fill_matrices(N, d_model=64, scale=8.0):

    # Shared latent structure
    latent = np.random.randn(N, d_model).astype(np.float32)

    # Create smoother token relationships
    for i in range(1, N):
        latent[i] = (
            0.7 * latent[i - 1] +
            0.3 * latent[i]
        )

    # Q and K are related but NOT identical
    Q_fp = latent + 0.2 * np.random.randn(N, d_model)
    K_fp = latent + 0.2 * np.random.randn(N, d_model)

    # Normalize rows
    Q_fp /= np.linalg.norm(Q_fp, axis=1, keepdims=True) + 1e-6
    K_fp /= np.linalg.norm(K_fp, axis=1, keepdims=True) + 1e-6

    # Smaller quantization scale
    Q = np.clip(
        np.round(Q_fp * scale),
        -127,
        127
    ).astype(np.int8)

    K = np.clip(
        np.round(K_fp * scale),
        -127,
        127
    ).astype(np.int8)

    return Q, K

# ------------------------------------------------------------
# INT8 GEMM -> INT32
# ------------------------------------------------------------
def matmul_int8(Q, K):

    return np.matmul(
        Q.astype(np.int32),
        K.T.astype(np.int32)
    )


# ------------------------------------------------------------
# INT32 -> FP16
# ------------------------------------------------------------
def int32_to_fp16(intTile):

    return intTile.astype(np.float16)


# ------------------------------------------------------------
# Normalize in FP16
# ------------------------------------------------------------
def norm_fp16tile(fpTile, d):

    return fpTile / np.float16(np.sqrt(d))


# ------------------------------------------------------------
# Online Softmax in FP16
# ------------------------------------------------------------
def online_softmax_fp16(normTile, N):

    sfmTile = np.zeros((N, N), dtype=np.float16)

    for j in range(N):

        m = np.float16(-65504.0)  # minimum finite fp16
        l = np.float16(0.0)

        # Pass 1
        for i in range(N):

            x = normTile[j, i]

            if x > m:
                l = l * np.exp(m - x).astype(np.float16) + np.float16(1.0)
                m = x
            else:
                l = l + np.exp(x - m).astype(np.float16)

        # Pass 2
        for i in range(N):

            sfmTile[j, i] = (
                np.exp(normTile[j, i] - m).astype(np.float16)
                / l
            )

    return sfmTile


# ------------------------------------------------------------
# Save outputs
# ------------------------------------------------------------
def save_files(Q, K, intTile, sfmTile):

    np.savetxt('Q.txt', Q, fmt='%4d')
    np.savetxt('K.txt', K, fmt='%4d')
    np.savetxt('intTile.txt', intTile, fmt='%8d')
    np.savetxt('sfmTile.txt', sfmTile, fmt='%1.6f')


# ------------------------------------------------------------
# Plot
# ------------------------------------------------------------
def plot_attention(sfmTile):

    plt.figure(figsize=(6, 5))
    plt.imshow(sfmTile.astype(np.float32), cmap='viridis')
    plt.colorbar(label='Attention Weight')
    plt.title('FP16 Quantized Attention')
    plt.xlabel('Key Tokens')
    plt.ylabel('Query Tokens')
    plt.tight_layout()
    plt.show()


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
if __name__ == '__main__':

    N = 8
    d_model = 64

    # Generate realistic quantized Q/K
    Q, K = fill_matrices(N, d_model=d_model)

    # INT8 x INT8 -> INT32
    intTile = matmul_int8(Q, K)

    # INT32 -> FP16
    fp16Tile = int32_to_fp16(intTile)

    # Normalize
    normTile = norm_fp16tile(fp16Tile, d_model)

    # FP16 softmax
    sfmTile = online_softmax_fp16(normTile, N)

    # Save outputs
    save_files(Q, K, intTile, sfmTile)

    # Plot
    plot_attention(sfmTile)

    print("\nFP16 Softmax Attention Matrix:\n")
    print(sfmTile)