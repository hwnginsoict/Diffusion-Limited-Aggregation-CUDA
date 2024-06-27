#include <iostream>
#include <sys/time.h>
#include <cstdlib>
#include <cstdio>
#include <cuda_runtime.h>

__device__ int width;
__device__ int height;
__device__ int* map;

int cwidth;
int cheight;
int* cmap;

double cpuSecond() {
    struct timeval tp;
    gettimeofday(&tp, NULL);
    return ((double)tp.tv_sec + (double)tp.tv_usec * 1.e-6);
}

typedef struct {
    int x;
    int y;
    int state;
    uint seed;
} Point;

__device__ float random_number(int seed){
    int x = seed;
    int m = 65537;
    int a = 75;
    int k = 10;
    for(int i=0; i<k; i++){
      x = (a*x)%m;
    }
    float ans = (float)x/(float)m;
    return ans;
}

__global__ void init_particles(Point* points, int number) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < number) {
        Point p;
        p.state = 0;
        p.x = (int)(random_number(i)*width);
        p.y = (int)(random_number((int)(random_number(i)*65537))*height);
        p.seed = i;
        points[i] = p;
    }
}

__device__ void move(Point& p) {
    p.seed = (int)(random_number(p.seed)*65537);
    int mov = p.seed % 4;
    if (mov == 0) {
        p.x += 1;
    } else if (mov == 1) {
        p.x -= 1;
    } else if (mov == 2) {
        p.y += 1;
    } else {
        p.y -= 1;
    }

    // condition
    if (p.x >= width) {
        p.x = 0;
    } else if (p.x < 0) {
        p.x = width - 1;
    }

    if (p.y >= height) {
        p.y = 0;
    } else if (p.y < 0) {
        p.y = height - 1;
    }
}

__device__ int check_occupied(int x, int y) {
    for (int x1 = -1; x1 <= 1; x1++) {
        for (int y1 = -1; y1 <= 1; y1++) {
            if (y1 == 0 && x1 == 0) continue;
            if (x1 + x < 0 || x1 + x >= width) continue;
            if (y1 + y < 0 || y1 + y >= height) continue;
            int j = ((y + y1) * width) + (x + x1);
            if (map[j] > 0) {
                return 1;
            }
        }
    }
    return 0;
}

__device__ void occupy(Point& p) {
    p.state = 1;
    int i = p.y * width + p.x;
    map[i] = 1;
}

__global__ void fill(Point* points, int number, int* changed) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < number) {
        Point p = points[i];
        if (p.state == 1) return;
        if (check_occupied(p.x, p.y)) {
            points[i].state = 1;
            int idx = p.y * width + p.x;
            map[idx] = 1;
            *changed = 1; // Indicate that a change was made
        }
    }
}

__global__ void move_particles(Point* points, int number) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < number) {
        if (points[i].state == 0) {
            move(points[i]);
        }
    }
}

void save_map(const char* file_name, int* map, int width, int height) {
    FILE* fp = fopen(file_name, "w");
    if (fp == NULL) {
        printf("Error opening the file %s\n", file_name);
        return;
    }
    for (int i = 0; i < width * height; i++) {
        if (i % width == 0) {
            fprintf(fp, "\n");
        }
        fprintf(fp, "%d ", map[i]);
    }
    fclose(fp);
}

int main() {
    cwidth = 200;
    cheight = 200;
    int number = 3000;
    int steps = 10000;
    int sx = 100;
    int sy = 100;
    int si = sy * cwidth + sx;

    double iStart = cpuSecond();

    cmap = (int*)malloc(sizeof(int) * cwidth * cheight);
    cudaMemcpyToSymbol(width, &cwidth, sizeof(int));
    cudaMemcpyToSymbol(height, &cheight, sizeof(int));
    int* d_map;
    cudaMalloc(&d_map, sizeof(int) * cwidth * cheight);
    cudaMemcpyToSymbol(map, &d_map, sizeof(int*));
    cudaMemcpy(d_map, cmap, sizeof(int) * cwidth * cheight, cudaMemcpyHostToDevice);

    Point* points;
    cudaMalloc(&points, sizeof(Point) * number);

    const int base = 1;
    int init_threads = base;
    int init_blocks = (number + base - 1) / base;
    if (number < base) {
        init_threads = number;
        init_blocks = 1;
    }
    init_particles<<<init_blocks, init_threads>>>(points, number);
    cudaDeviceSynchronize();

    printf("Initialization time: %.3f milliseconds\n", 1000 * (cpuSecond() - iStart));
    double sStart = cpuSecond();

    // Initialize starting point on device
    int initial_value = 1;
    cudaMemcpy(&d_map[si], &initial_value, sizeof(int), cudaMemcpyHostToDevice);

    int* d_changed;
    cudaMalloc(&d_changed, sizeof(int));

    for (int i = 0; i < steps; i++) {
        int changed;
        do {
            changed = 0;
            cudaMemcpy(d_changed, &changed, sizeof(int), cudaMemcpyHostToDevice);

            fill<<<init_blocks, init_threads>>>(points, number, d_changed);
            cudaDeviceSynchronize();

            cudaMemcpy(&changed, d_changed, sizeof(int), cudaMemcpyDeviceToHost);
        } while (changed);

        move_particles<<<init_blocks, init_threads>>>(points, number);
        cudaDeviceSynchronize();
    }

    printf("Simulation time: %.3f milliseconds\n", 1000 * (cpuSecond() - sStart));

    cudaMemcpy(cmap, d_map, sizeof(int) * cwidth * cheight, cudaMemcpyDeviceToHost);

    save_map("output_map.txt", cmap, cwidth, cheight);
    free(cmap);
    cudaFree(d_map);
    cudaFree(points);
    cudaFree(d_changed);
    return 0;
}