import matplotlib.pyplot as plt

# Memory usage data
memory_labels = ["Small Dataset", "Large Dataset"]
count_sort_memory = [2, 3]  # Moderate, High
merge_sort_memory = [1, 2]  # Low, Moderate

# Plotting memory usage comparison as a bar chart
bar_width = 0.35
x = range(len(memory_labels))

plt.figure(figsize=(10, 5))
plt.bar(x, count_sort_memory, width=bar_width, label="Distributed Count Sort", color='skyblue')
plt.bar([i + bar_width for i in x], merge_sort_memory, width=bar_width, label="Distributed Merge Sort", color='salmon')
plt.xlabel("Dataset Size")
plt.ylabel("Memory Usage (1=Low, 2=Moderate, 3=High)")
plt.title("Memory Usage Comparison for Distributed Sorting Algorithms")
plt.xticks([i + bar_width / 2 for i in x], memory_labels)
plt.legend()
plt.show()
