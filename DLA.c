#include <iostream>
#include <sys/time.h>
#include <cstdlib>
#include <cstdio>

int width;
int height;
int* map;

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

float random_number(int seed){
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

void initialize(Point* points, int number) {
    for (int i = 0; i < number; i++) {
        Point p;
        p.state = 0;
        p.x = (int)(random_number(i)*width);
        p.y = (int)(random_number((int)(random_number(i)*65537))*height);
        p.seed = i;
        points[i] = p;
    }
}

void move(Point &p) {
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

int check_occupied(int x, int y) {
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

void occupy(Point &p) {
    p.state = 1;
    int i = p.y * width + p.x;
    map[i] = 1;
}

void fill(Point* points, int number) {
    int changed;
    do {
        changed = 0;
        for (int i = 0; i < number; i++) {
            Point p = points[i];
            if (p.state == 1) continue;
            if (check_occupied(p.x, p.y)) {
                points[i].state = 1;
                int idx = p.y * width + p.x;
                map[idx] = 1;
                changed = 1;
            }
        }
    } while (changed);
}

void move_particles(Point* points, int number) {
    for (int i = 0; i < number; i++) {
        if (points[i].state == 0) {
            move(points[i]);
        }
    }
}

void save_map(const char* file_name, int* map, int width, int height) {
    FILE *fp = fopen(file_name, "w");
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
    width = 200;
    height = 200;
    int number = 3000;
    int steps = 10000;
    int sx = 100;
    int sy = 100;
    int si = sy * width + sx;

    double iStart = cpuSecond();

    map = (int*)malloc(sizeof(int) * width * height);

    Point* points = (Point*)malloc(sizeof(Point) * number);
    initialize(points, number);

    printf("Initialization time: %.3f milliseconds\n", 1000 * (cpuSecond() - iStart));
    double sStart = cpuSecond();

    map[si] = 1;

    for (int i = 0; i < steps; i++) {
        fill(points, number);
        move_particles(points, number);
    }

    printf("Simulation time: %.3f milliseconds\n", 1000 * (cpuSecond() - sStart));

    save_map("output_map1.txt", map, width, height);
    free(map);
    free(points);
    return 0;
}