<template>
    <div>
        <h1>Materialized View Administration</h1>
        <br>
        <button v-on:click="getMvRefreshLogData">Get MV Refresh Log</button>
        <button v-on:click="getMvRefreshPriorityData">Get MV Refresh Priorities</button>
        <br><br>
        <div v-if="items.length > 0" class="refresh-data">
            <b-table striped hover :items="items" :fields="fields"></b-table>
        </div>
        <div v-if="items2.length > 0" class="refresh-data">
            <b-table striped hover :items="items2" :fields="fields2"></b-table>
        </div>
    </div>
</template>

<script>
    export default {
        name: "MvRefreshLog",
        data() {
            return {
                fields: [
                    {
                        key: 'owner',
                        sortable: false
                    },
                    {
                        key: 'mvName',
                        sortable: true,
                        label: "Materialized View name"
                    },
                    {
                        key: 'startDate',
                        sortable: true,
                        label: "Start date"
                    },
                    {
                        key: 'endDate',
                        sortable: true,
                        label: "End date"
                    },
                    {
                        key: 'dependencyPath',
                        sortable: false,
                        label: "Dependency path"
                    },
                    {
                        key: 'priority',
                        sortable: false,
                        label: "Priority"
                    }
                ],
                items: [],
                fields2: [
                    {
                        key: 'owner',
                        sortable: false
                    },
                    {
                        key: 'mvName',
                        sortable: true,
                        label: "Materialized View name"
                    },
                    {
                        key: 'priority',
                        sortable: true,
                        label: "Priority"
                    }
                ],
                items2: []
            };
        },
        methods: {
            getMvRefreshLogData() {
                fetch("/public/MvRefreshLog.json")
                    .then(response => response.json())
                    .then(data => (this.items = data));

                this.items2 = [];
            },
            getMvRefreshPriorityData() {
                fetch("/public/MvPriorities.json")
                    .then(response => response.json())
                    .then(data => (this.items2 = data));

                this.items = [];
            }
        }
    };
</script>

<style>
    button {
        padding:10px;
        background-color: #1aa832;
        color: white;
        border: 1px solid #ccc;
    }
    .refresh-data {
        display: flex;
        text-align: left;
        margin-top: 20px;
        margin-left: 20px;
        border-bottom: 2px solid #ccc;
        padding: 20px;
    }
</style>